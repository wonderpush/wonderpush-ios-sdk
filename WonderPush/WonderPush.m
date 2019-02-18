/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <UserNotifications/UserNotifications.h>
#import "WPUtil.h"
#import "WonderPush_private.h"
#import "WPAppDelegate.h"
#import "WPNotificationCenterDelegate.h"
#import "WPConfiguration.h"
#import "WPDialogButtonHandler.h"
#import "WPAPIClient.h"
#import "WPJsonUtil.h"
#import "WPLog.h"
#import "WPJsonSyncInstallationCustom.h"
#import "WonderPushConcreteAPI.h"
#import "WonderPushLogErrorAPI.h"
#import "WPHTMLInAppController.h"

static UIApplicationState _previousApplicationState = UIApplicationStateInactive;

static BOOL _isReady = NO;
static BOOL _isInitialized = NO;
static BOOL _isReachable = NO;

static BOOL _beforeInitializationUserIdSet = NO;
static NSString *_beforeInitializationUserId = nil;

static BOOL _userNotificationCenterDelegateInstalled = NO;

static NSString *_notificationFromAppLaunchCampaignId = nil;
static NSString *_notificationFromAppLaunchNotificationId = nil;
__weak static id<WonderPushDelegate> _delegate = nil;

@implementation WonderPush

static NSString *_currentLanguageCode = nil;
static NSArray *validLanguageCodes = nil;
static BOOL _requiresUserConsent = NO;
static id<WonderPushAPI> wonderPushAPI = nil;
static NSMutableDictionary *safeDeferWithConsentIdToBlock = nil;
static NSMutableOrderedSet *safeDeferWithConsentIdentifiers = nil;
static UIStoryboard *storyboard = nil;
+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        storyboard = [UIStoryboard storyboardWithName:@"WonderPush" bundle:[self bundle]];
        wonderPushAPI = [WonderPushNotInitializedAPI new];
        safeDeferWithConsentIdToBlock = [NSMutableDictionary new];
        safeDeferWithConsentIdentifiers = [NSMutableOrderedSet new];
        [[NSNotificationCenter defaultCenter] addObserverForName:WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED object:self queue:nil usingBlock:^(NSNotification *notification) {
            BOOL hasUserConsent = [notification.userInfo[WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED_KEY] boolValue];
            if (hasUserConsent) {
                // Execute deferred
                @synchronized(safeDeferWithConsentIdentifiers) {
                    for (NSString *identifier in [safeDeferWithConsentIdentifiers array]) {
                        void(^block)(void) = safeDeferWithConsentIdToBlock[identifier];
                        if (block) block();
                    }
                    [safeDeferWithConsentIdentifiers removeAllObjects];
                    [safeDeferWithConsentIdToBlock removeAllObjects];
                }
                // Ensure we have an @APP_OPEN
                [self onInteractionLeaving:NO];
            }
        }];
        NSNumber *overrideSetLogging = [WPConfiguration sharedConfiguration].overrideSetLogging;
        if (overrideSetLogging != nil) {
            WPLog(@"OVERRIDE setLogging: %@", overrideSetLogging);
            WPLogEnable([overrideSetLogging boolValue]);
        }
        // Initialize some constants
        validLanguageCodes = @[@"af", @"ar", @"be",
                               @"bg", @"bn", @"ca", @"cs", @"da", @"de", @"el", @"en", @"en_GB", @"en_US",
                               @"es", @"es_ES", @"es_MX", @"et", @"fa", @"fi", @"fr", @"fr_FR", @"fr_CA",
                               @"he", @"hi", @"hr", @"hu", @"id", @"is", @"it", @"ja", @"ko", @"lt", @"lv",
                               @"mk", @"ms", @"nb", @"nl", @"pa", @"pl", @"pt", @"pt_PT", @"pt_BR", @"ro",
                               @"ru", @"sk", @"sl", @"sq", @"sr", @"sv", @"sw", @"ta", @"th", @"tl", @"tr",
                               @"uk", @"vi", @"zh", @"zh_CN", @"zh_TW", @"zh_HK",
                               ];

        // setIsReady:YES when initialization notification received
        [[NSNotificationCenter defaultCenter] addObserverForName:WP_NOTIFICATION_INITIALIZED object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self setIsReady:YES];
        }];
    });
}
+ (NSBundle *) bundle
{
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[WonderPush class]];
    NSString *bundlePath = [[frameworkBundle resourcePath] stringByAppendingPathComponent:@"WonderPush.bundle"];
    return [NSBundle bundleWithPath:bundlePath];

}
+ (void) setRequiresUserConsent:(BOOL)requiresUserConsent
{
    BOOL hadUserConsent = [self hasUserConsent];
    _requiresUserConsent = requiresUserConsent;
    if (_isInitialized) {
        WPLog(@"Calling setRequiresUserConsent after `setClientId:secret:` is wrong. Please update your code.");
        BOOL nowHasUserConsent = [self hasUserConsent];
        if (hadUserConsent != nowHasUserConsent) {
            [self hasUserConsentChanged:nowHasUserConsent];
        }
    }
}
+ (void) setUserConsent:(BOOL)userConsent
{
    BOOL hadUserConsent = [self hasUserConsent];
    [[WPConfiguration sharedConfiguration] setUserConsent:userConsent];
    BOOL nowHasUserConsent = [self hasUserConsent];
    if (_isInitialized && hadUserConsent != nowHasUserConsent) {
        [self hasUserConsentChanged:nowHasUserConsent];
    }
}
+ (BOOL) getUserConsent
{
    return [WPConfiguration sharedConfiguration].userConsent;
}
+ (BOOL) hasUserConsent
{
    return !_requiresUserConsent || [self getUserConsent];
}
+ (void) hasUserConsentChanged:(BOOL)hasUserConsent
{
    if (!_isInitialized) WPLog(@"hasUserConsentChanged called before SDK initialization");
    WPLogDebug(@"User consent changed to %@", hasUserConsent ? @"YES": @"NO");
    [wonderPushAPI deactivate];
    if (hasUserConsent) {
        wonderPushAPI = [WonderPushConcreteAPI new];
    } else {
        wonderPushAPI = [WonderPushNoConsentAPI new];
    }
    [wonderPushAPI activate];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED
         object:self
         userInfo:@{
                    WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED_KEY : [NSNumber numberWithBool:hasUserConsent]
                    }];
    });
}

+ (void) safeDeferWithConsent:(void(^)(void))block
{
    [self safeDeferWithConsent:block identifier:[[NSUUID UUID] UUIDString]];
}
+ (void) safeDeferWithConsent:(void(^)(void))block identifier:(NSString *)identifier
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self hasUserConsent]) {
            block();
        } else {
            @synchronized(safeDeferWithConsentIdentifiers) {
                [safeDeferWithConsentIdentifiers addObject:identifier];
                [safeDeferWithConsentIdToBlock setObject:block forKey:identifier];
            }
        }
    });
}
+ (void) setLogging:(BOOL)enable
{
    NSNumber *overrideSetLogging = [WPConfiguration sharedConfiguration].overrideSetLogging;
    if (overrideSetLogging != nil) {
        enable = [overrideSetLogging boolValue];
    }
    WPLogEnable(enable);
}

+ (BOOL) isInitialized
{
    return _isInitialized;
}

+ (void) setIsInitialized:(BOOL)isInitialized
{
    _isInitialized = isInitialized;
}

+ (BOOL) isReady
{
    return _isReady;
}

+ (void) setIsReady:(BOOL)isReady
{
    _isReady = isReady;
}

+ (BOOL) isReachable
{
    return _isReachable;
}

+ (void) setIsReachable:(BOOL)isReachable
{
    _isReachable = isReachable;
}

+ (void) setUserId:(NSString *)userId
{
    if ([@"" isEqualToString:userId]) userId = nil;
    if (![self isInitialized]) {
        WPLogDebug(@"setUserId:%@ (before initialization)", userId);
        _beforeInitializationUserIdSet = YES;
        _beforeInitializationUserId = userId;
        // Now we wait for [WonderPush setClientId:secret:] to be called
        return;
    }
    WPLogDebug(@"setUserId:%@ (after initialization)", userId);
    _beforeInitializationUserIdSet = NO;
    _beforeInitializationUserId = nil;
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    if ((userId == nil && configuration.userId != nil)
        || (userId != nil && ![userId isEqualToString:configuration.userId])) {
        [self initForNewUser:userId];
    } // else: nothing needs to be done
}

+ (void) setClientId:(NSString *)clientId secret:(NSString *)secret
{
    WPLogDebug(@"setClientId:%@ secret:<redacted>", clientId);
    NSException* invalidArgumentException = nil;

    if (clientId == nil) {
        invalidArgumentException = [NSException
                                    exceptionWithName:@"InvalidArgumentException"
                                    reason:@"Please set 'clientId' argument of [WonderPush setClientId:secret] method"
                                    userInfo:nil];
    } else if (secret == nil) {
        invalidArgumentException = [NSException
                                    exceptionWithName:@"InvalidArgumentException"
                                    reason:@"Please set 'secret' argument of [WonderPush setClientId:secret] method"
                                    userInfo:nil];
    }
    if (invalidArgumentException != nil) {
        @throw invalidArgumentException;
    }

    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    configuration.clientId = clientId;
    configuration.clientSecret = secret;
    if ((configuration.clientId == nil && [configuration getStoredClientId] != nil)
        || (configuration.clientId != nil && ![configuration.clientId isEqualToString: [configuration getStoredClientId]]))
    {
        [configuration setStoredClientId:clientId];
        // clientId changed reseting token
        configuration.accessToken = nil;
        configuration.sid = nil;
    }
    [self setIsInitialized:YES];
    [self initForNewUser:(_beforeInitializationUserIdSet ? _beforeInitializationUserId : configuration.userId)];
    [self hasUserConsentChanged:[self hasUserConsent]];
}

+ (void) initForNewUser:(NSString *)userId
{
    WPLogDebug(@"initForNewUser:%@", userId);
    [self setIsReady:NO];
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    [configuration changeUserId:userId];
    [WPJsonSyncInstallationCustom forCurrentUser]; // ensures static initialization is done
    [self safeDeferWithConsent:^{
        void (^init)(void) = ^{
            [self setIsReady:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_INITIALIZED
                                                                object:self
                                                              userInfo:nil];
            [WonderPush updateInstallationCoreProperties];
            [self refreshDeviceTokenIfPossible];
        };
        // Fetch anonymous access token right away
        BOOL isFetching = [[WPAPIClient sharedClient] fetchAccessTokenIfNeededAndCall:^(NSURLSessionTask *task, id responseObject) {
            init();
        } failure:^(NSURLSessionTask *task, NSError *error) {} forUserId:userId];
        if (NO == isFetching) {
            init();
        }
    } identifier:@"initForNewUser"];
}

+ (BOOL) getNotificationEnabled
{
    return [wonderPushAPI getNotificationEnabled];
}

+ (void) setNotificationEnabled:(BOOL)enabled
{
    WPLogDebug(@"setNotificationEnabled:%@", enabled ? @"YES" : @"NO");
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }
    [wonderPushAPI setNotificationEnabled:enabled];

}

+ (BOOL) isNotificationForWonderPush:(NSDictionary *)userInfo
{
    if ([userInfo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *wonderpushData = [userInfo dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
        return !!wonderpushData;
    } else {
        WPLogDebug(@"isNotificationForWonderPush: received a non NSDictionary: %@", userInfo);
    }
    return NO;
}

+ (BOOL) isDataNotification:(NSDictionary *)userInfo
{
    if (![WonderPush isNotificationForWonderPush:userInfo])
        return NO;
    return [WP_PUSH_NOTIFICATION_DATA isEqualToString:[([userInfo dictionaryForKey:WP_PUSH_NOTIFICATION_KEY] ?: @{}) stringForKey:WP_PUSH_NOTIFICATION_TYPE_KEY]];
}

+ (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    [wonderPushAPI trackInternalEvent:type eventData:data customData:customData];
}

+ (void) refreshDeviceTokenIfPossible
{
    [wonderPushAPI refreshDeviceTokenIfPossible];
}

#pragma mark - WonderPushDelegate
+ (void) setDelegate:(id<WonderPushDelegate>)delegate
{
    _delegate = delegate;
}

#pragma mark - Application delegate

+ (void) setupDelegateForApplication:(UIApplication *)application
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    [WPAppDelegate setupDelegateForApplication:application];
}

+ (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return NO;
    if ([WPAppDelegate isAlreadyRunning]) return NO;

    if ([self getNotificationEnabled]) {
        [WPUtil registerToPushNotifications];
    }

    if (![WPUtil hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler] // didReceiveRemoteNotification will be called in such a case
        && launchOptions != nil
    ) {
        NSDictionary *notificationDictionary = [launchOptions dictionaryForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if ([notificationDictionary isKindOfClass:[NSDictionary class]]) {
            _notificationFromAppLaunchCampaignId = nil;
            _notificationFromAppLaunchNotificationId = nil;
            if ([WonderPush isNotificationForWonderPush:notificationDictionary]) {
                NSDictionary *wonderpushData = [notificationDictionary dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
                _notificationFromAppLaunchCampaignId = [wonderpushData stringForKey:@"c"];
                _notificationFromAppLaunchNotificationId = [wonderpushData stringForKey:@"n"];
            }
            return [self handleNotification:notificationDictionary];
        }
    }
    return NO;
}

+ (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    [WonderPush handleNotification:userInfo];
    if (completionHandler) {
        completionHandler(UIBackgroundFetchResultNewData);
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
#pragma clang diagnostic pop
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    [WonderPush handleNotification:notification.userInfo withOriginalApplicationState:UIApplicationStateInactive];
}

+ (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    [self handleNotification:userInfo];
}

+ (void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    NSString *newToken = [deviceToken description];
    [WonderPush setDeviceToken:newToken];
}

+ (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    WPLogDebug(@"Failed to register to push notifications: %@", error);
    [WonderPush setDeviceToken:nil];
}

+ (void) applicationDidBecomeActive:(UIApplication *)application;
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    BOOL comesBackFromTemporaryInactive = _previousApplicationState == UIApplicationStateActive;
    _previousApplicationState = UIApplicationStateActive;

    // Show any queued notifications
    if ([self hasUserConsent]) {
        UIApplicationState originalApplicationState = comesBackFromTemporaryInactive ? UIApplicationStateActive : UIApplicationStateInactive;
        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        NSArray *queuedNotifications = [configuration getQueuedNotifications];
        for (NSDictionary *queuedNotification in queuedNotifications) {
            if (![queuedNotification isKindOfClass:[NSDictionary class]]) continue;
            [self handleNotification:queuedNotification withOriginalApplicationState:originalApplicationState];
        }
        [configuration clearQueuedNotifications];
    }

    [self onInteractionLeaving:NO];
}

+ (void) applicationDidEnterBackground:(UIApplication *)application
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    _previousApplicationState = UIApplicationStateBackground;

    [WPJsonSyncInstallationCustom flush];

    // Send queued notifications as LocalNotifications
    if ([self hasUserConsent]) {
        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        if (![WPUtil currentApplicationIsInForeground]) {
            NSArray *queuedNotifications = [configuration getQueuedNotifications];
            for (NSDictionary *userInfo in queuedNotifications) {
                if (![userInfo isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *aps = [userInfo dictionaryForKey:@"aps"];
                NSDictionary *alertDict = [aps dictionaryForKey:@"alert"];
                NSString *title = alertDict ? [alertDict stringForKey:@"title"] : nil;
                NSString *alert = alertDict ? [alertDict stringForKey:@"body"] : [aps stringForKey:@"alert"];
                NSString *sound = [aps stringForKey:@"sound"];
                if (@available(iOS 10.0, *)) {
                    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                    content.title = title;
                    content.body = alert;
                    if (sound) content.sound = [UNNotificationSound soundNamed:sound];
                    content.userInfo = userInfo;
                    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString] content:content trigger:nil];
                    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
                } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    UILocalNotification *notification = [[UILocalNotification alloc] init];
                    notification.alertBody = alert;
                    notification.soundName = [aps stringForKey:@"sound"];
                    notification.userInfo = userInfo;
                    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
#pragma clang diagnostic pop
                }
            }
        }
        [configuration clearQueuedNotifications];
    }

    [self onInteractionLeaving:YES];
}


#pragma mark - UserNotificationCenter delegate

+ (void) setupDelegateForUserNotificationCenter __IOS_AVAILABLE(10.0)
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (!_userNotificationCenterDelegateInstalled) {
        WPLogDebug(@"Setting the notification center delegate");
        [WPNotificationCenterDelegate setupDelegateForNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]];
    }
}

+ (void) setUserNotificationCenterDelegateInstalled:(BOOL)enabled
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    _userNotificationCenterDelegateInstalled = enabled;
}


+ (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    WPLogDebug(@"userNotificationCenter:%@ willPresentNotification:%@ withCompletionHandler:", center, notification);
    NSDictionary *userInfo = notification.request.content.userInfo;
    WPLogDebug(@"              userInfo:%@", userInfo);

    UNNotificationPresentationOptions presentationOptions = UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound;

    if (![self isNotificationForWonderPush:userInfo]) {
        WPLogDebug(@"Notification is not for WonderPush");
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            WPLogDebug(@"Defaulting to not showing the notification");
            presentationOptions = UNNotificationPresentationOptionNone;
        }
        completionHandler(presentationOptions);
        return;
    }

    // Ensure that we display the notification even if the application is in foreground
    NSDictionary *wpData = [userInfo dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
    NSDictionary *apsForeground = [wpData dictionaryForKey:@"apsForeground"];
    if (!apsForeground || apsForeground.count == 0) apsForeground = nil;
    BOOL apsForegroundAutoOpen = NO;
    BOOL apsForegroundAutoDrop = NO;
    if (apsForeground) {
        apsForegroundAutoOpen = [[apsForeground numberForKey:@"autoOpen"] isEqual:@YES];
        apsForegroundAutoDrop = [[apsForeground numberForKey:@"autoDrop"] isEqual:@YES];
    }
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive && (apsForegroundAutoDrop || apsForegroundAutoOpen)) {
        WPLogDebug(@"NOT displaying the notification");
        presentationOptions = UNNotificationPresentationOptionNone;
    } else {
        WPLogDebug(@"WILL display the notification");
    }

    completionHandler(presentationOptions);
}

+ (void) userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler
{
    WPLogDebug(@"userNotificationCenter:%@ didReceiveNotificationResponse:%@ withCompletionHandler:", center, response);
    [self handleNotificationOpened:response.notification.request.content.userInfo];
    completionHandler();
}


#pragma mark - Core information

+ (NSString *) userId
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.userId;    
}

+ (NSString *) installationId
{
    return [wonderPushAPI installationId];
}

+ (NSString *) deviceId
{
    return [wonderPushAPI deviceId];
}

+ (NSString *) pushToken
{
    return [wonderPushAPI pushToken];
}

+ (NSString *) accessToken
{
    return [wonderPushAPI accessToken];
}


#pragma mark - Installation data and events

+ (NSDictionary *) getInstallationCustomProperties
{
    return [wonderPushAPI getInstallationCustomProperties];
}

+ (void) putInstallationCustomProperties:(NSDictionary *)customProperties
{
    WPLogDebug(@"putInstallationCustomProperties:%@", customProperties);
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }
    [wonderPushAPI putInstallationCustomProperties:customProperties];
}

+ (void)receivedFullInstallationCustomPropertiesFromServer:(NSDictionary *)custom updateDate:(NSDate *)installationUpdateDate
{
    WPLogDebug(@"Synchronizing installation custom fields");
    custom = custom ?: @{};
    [[WPJsonSyncInstallationCustom forCurrentUser] receiveState:custom resetSdkState:false];
}

+ (void) trackNotificationOpened:(NSDictionary *)notificationInformation
{
    [self trackInternalEvent:@"@NOTIFICATION_OPENED" eventData:notificationInformation customData:nil];
}

+ (void) trackNotificationReceived:(NSDictionary *)userInfo
{
    if (![WonderPush isNotificationForWonderPush:userInfo]) return;
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    NSDictionary *wpData = [userInfo dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
    id receipt        = conf.overrideNotificationReceipt ?: [wpData nullsafeObjectForKey:@"receipt"];
    if (receipt && [[receipt class] isEqual:[@YES class]] && [receipt isEqual:@NO]) return; // lengthy but warning-free test for `receipt == @NO`, both properly distinguishes 0 from @NO, whereas `[receipt isEqual:@NO]` alone does not
    id campagnId      = [wpData stringForKey:@"c"];
    id notificationId = [wpData stringForKey:@"n"];
    NSMutableDictionary *notificationInformation = [NSMutableDictionary new];
    if (campagnId)      notificationInformation[@"campaignId"]     = campagnId;
    if (notificationId) notificationInformation[@"notificationId"] = notificationId;
    conf.lastReceivedNotificationDate = [NSDate date];
    conf.lastReceivedNotification = notificationInformation;
    [self trackInternalEvent:@"@NOTIFICATION_RECEIVED" eventData:notificationInformation customData:nil];
}

+ (void) trackEvent:(NSString*)type
{
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }
    WPLogDebug(@"trackEvent:%@", type);
    [wonderPushAPI trackEvent:type];
}

+ (void) trackEvent:(NSString*)type withData:(NSDictionary *)data
{
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }
    WPLogDebug(@"trackEvent:%@ withData:%@", type, data);
    [wonderPushAPI trackEvent:type withData:data];
}


#pragma mark - push notification types handling

+ (void) handleTextNotification:(NSDictionary *)wonderPushData
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[wonderPushData stringForKey:@"title"] message:[wonderPushData stringForKey:@"message"] preferredStyle:UIAlertControllerStyleAlert];

    NSArray *buttons = [wonderPushData arrayForKey:@"buttons"];
    WPDialogButtonHandler *buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.notificationConfiguration = wonderPushData;
    buttonHandler.buttonConfiguration = buttons;
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        int i = -1;
        for (NSDictionary *button in buttons) {
            int index = ++i;
            if (![button isKindOfClass:[NSDictionary class]]) continue;
            [alert addAction:[UIAlertAction actionWithTitle:[button stringForKey:@"label"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [buttonHandler clickedButtonAtIndex:index];
            }]];
        }
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [buttonHandler clickedButtonAtIndex:-1];
        }]];
    }

    __block void (^presentBlock)(void) = ^{
        if ([UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), presentBlock);
        } else {
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            presentBlock = nil;
        }
    };
    dispatch_async(dispatch_get_main_queue(), presentBlock);
}

+ (void) handleHtmlNotification:(NSDictionary*)wonderPushData
{
    NSArray *buttons = [wonderPushData objectForKey:@"buttons"];
    WPDialogButtonHandler *buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.buttonConfiguration = buttons;
    buttonHandler.notificationConfiguration = wonderPushData;
    NSMutableArray *alertButtons = [[NSMutableArray alloc] initWithCapacity:MIN(1, [buttons count])];
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        int i = -1;
        for (NSDictionary *button in buttons) {
            ++i;
            [alertButtons addObject:[WPHTMLInAppAction actionWithTitle:[button valueForKey:@"label"] block:^(WPHTMLInAppAction *action) {
                [buttonHandler clickedButtonAtIndex:i];
            }]];
        }
    } else {
        [alertButtons addObject:[WPHTMLInAppAction actionWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL block:^(WPHTMLInAppAction *action) {
            [buttonHandler clickedButtonAtIndex:0];
        }]];
    }

    WPHTMLInAppController *controller = [storyboard instantiateViewControllerWithIdentifier:@"HTMLInAppController"];
    controller.title = wonderPushData[@"title"];
    controller.actions = alertButtons;
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    controller.HTMLString = [wonderPushData stringForKey:@"message"];
    NSString *URLString = [wonderPushData valueForKey:@"url"];
    if (URLString) {
        controller.URL = [NSURL URLWithString:URLString];
    }
    if (!controller.HTMLString && !controller.URL) {
        WPLogDebug(@"Error the link / url provided is null");
        return;
    }
    __block void (^presentBlock)(void) = ^{
        if ([UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), presentBlock);
        } else {
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
            presentBlock = nil;
        }
    };
    dispatch_async(dispatch_get_main_queue(), presentBlock);
}

+ (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *)notification
{
    [wonderPushAPI executeAction:action onNotification:notification];
}

+ (void) setDeviceToken:(NSString *)deviceToken
{
    [wonderPushAPI setDeviceToken:deviceToken];
}

+ (void) hasAcceptedVisibleNotificationsWithCompletionHandler:(void(^)(BOOL result))handler;
{
    if (@available(iOS 10.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            handler(settings.alertSetting == UNNotificationSettingEnabled || settings.soundSetting == UNNotificationSettingEnabled || settings.badgeSetting == UNNotificationSettingEnabled);
        }];
    } else if (@available(iOS 8.0, *)) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            handler([[UIApplication sharedApplication] currentUserNotificationSettings].types != 0);
#pragma clang diagnostic pop
        } else {
            WPLog(@"Cannot resolve currentUserNotificationSettings");
            handler(NO);
        }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        handler([[UIApplication sharedApplication] enabledRemoteNotificationTypes] != 0);
#pragma clang diagnostic pop
    }
}

+ (BOOL) handleNotification:(NSDictionary*)notificationDictionary
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotification:%@", notificationDictionary);

    UIApplicationState appState = [UIApplication sharedApplication].applicationState;
    WPLogDebug(@"handleNotification: appState=%ld", (long)appState);

    // Reception tracking:
    // - only if background mode remote notification is enabled,
    //   otherwise the timing information is lost, and we already have notification opened tracking
    if ([WPUtil hasBackgroundModeRemoteNotification]) {
        // - when opening the application in response to a notification click,
        //   the application:didReceiveRemoteNotification:fetchCompletionHandler:
        //   method is called again, but in the inactive application state this time,
        //   we should not track reception again in such case.
        // - if the user is switching between apps, we are called just like if the app was active,
        //   but the application state is actually inactive too, test the previous state to distinguish.
        if (appState != UIApplicationStateInactive || _previousApplicationState == UIApplicationStateActive) {
            NSDictionary *wonderpushData = [notificationDictionary dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
            id atReceptionActions = [wonderpushData arrayForKey:@"receiveActions"];
            if (atReceptionActions) {
                for (id action in ((NSArray*)atReceptionActions)) {
                    if ([action isKindOfClass:[NSDictionary class]]) {
                        [self executeAction:action onNotification:wonderpushData];
                    }
                }
            }

            [WonderPush trackNotificationReceived:notificationDictionary];
        }
    }

    if (appState == UIApplicationStateBackground) {
        // The application won't run long enough to perform any scheduled updates of custom properties to the server
        // that may have been asked by receiveActions, flush now.
        // If we had no such modifications, this is still an opportunity to flush any interrupted calls.
        [WPJsonSyncInstallationCustom flush];
        WPLogDebug(@"handleNotification: return YES because state == background");
        return YES;
    }

    if (appState == UIApplicationStateInactive) {
        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        [configuration addToQueuedNotifications:notificationDictionary];
        WPLogDebug(@"handleNotification: queuing and returning YES because state == inactive");
        return YES;
    }

    WPLogDebug(@"handleNotification: continuing");
    return [self handleNotification:notificationDictionary withOriginalApplicationState:appState];
}

+ (BOOL) handleNotification:(NSDictionary*)notificationDictionary withOriginalApplicationState:(UIApplicationState)applicationState
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotification:%@ withOriginalApplicationState:%ld", notificationDictionary, (long)applicationState);

    NSDictionary *wonderpushData = [notificationDictionary dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
    NSDictionary *apsForeground = [wonderpushData dictionaryForKey:@"apsForeground"];
    if (!apsForeground || apsForeground.count == 0) apsForeground = nil;
    BOOL apsForegroundAutoOpen = NO;
    BOOL apsForegroundAutoDrop = NO;
    if (apsForeground) {
        apsForegroundAutoOpen = [[apsForeground numberForKey:@"autoOpen"] isEqual:@YES];
        apsForegroundAutoDrop = [[apsForeground numberForKey:@"autoDrop"] isEqual:@YES];
    }

    if (![WPUtil hasBackgroundModeRemoteNotification]) {
        // We have no remote-notification background execution mode but we try our best to honor receiveActions when we can
        // (they will not be honored for silent notifications, nor for regular notifications that are not clicked)
        NSDictionary *wonderpushData = [notificationDictionary dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
        id atReceptionActions = [wonderpushData arrayForKey:@"receiveActions"];
        if (atReceptionActions) {
            for (id action in ((NSArray*)atReceptionActions)) {
                if ([action isKindOfClass:[NSDictionary class]]) {
                    [self executeAction:action onNotification:wonderpushData];
                }
            }
        }
    }

    // Should we merely drop this notification if received in foreground?
    if (applicationState == UIApplicationStateActive && apsForegroundAutoDrop) {
        WPLogDebug(@"Dropping notification received in foreground like demanded");
        return NO;
    }

    NSDictionary *aps = [notificationDictionary dictionaryForKey:@"aps"];
    if (!aps || aps.count == 0) aps = nil;
    NSDictionary *apsAlert = aps ? [aps nullsafeObjectForKey:@"alert"] : nil;

    if (_userNotificationCenterDelegateInstalled && !apsForegroundAutoOpen) {
        WPLogDebug(@"handleNotification:withOriginalApplicationState: leaving to userNotificationCenter");
        return YES;
    } // else (if _userNotificationCenterDelegateInstalled), we must continue for autoOpen support

    // Should we simulate the system alert if the notification is received in foreground?
    if (
        // we only treat the case where the notification is received in foreground
        applicationState == UIApplicationStateActive
        // data notifications should never be displayed by our SDK
        && ![self isDataNotification:notificationDictionary]
        // if we should auto open the notification, skip to the else
        && !apsForegroundAutoOpen
        // we have some text to display
        && aps && apsAlert
    ) {
        WPLogDebug(@"handleNotification:withOriginalApplicationState: simulating system alert");

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSDictionary *infoDictionary = [mainBundle infoDictionary];
        NSDictionary *localizedInfoDictionary = [mainBundle localizedInfoDictionary];
        NSString *title = nil;
        NSString *alert = nil;
        NSString *action = nil;
        if ([apsAlert isKindOfClass:[NSDictionary class]]) {
            title = [apsAlert stringForKey:@"title-loc-key"];
            if (title) title = [WPUtil localizedStringIfPossible:title];
            if (title) {
                id locArgsId = [apsAlert arrayForKey:@"title-loc-args"];
                if (locArgsId) {
                    NSArray *locArgs = locArgsId;
                    title = [NSString stringWithFormat:title,
                             locArgs.count > 0 ? [locArgs objectAtIndex:0] : nil,
                             locArgs.count > 1 ? [locArgs objectAtIndex:1] : nil,
                             locArgs.count > 2 ? [locArgs objectAtIndex:2] : nil,
                             locArgs.count > 3 ? [locArgs objectAtIndex:3] : nil,
                             locArgs.count > 4 ? [locArgs objectAtIndex:4] : nil,
                             locArgs.count > 5 ? [locArgs objectAtIndex:5] : nil,
                             locArgs.count > 6 ? [locArgs objectAtIndex:6] : nil,
                             locArgs.count > 7 ? [locArgs objectAtIndex:7] : nil,
                             locArgs.count > 8 ? [locArgs objectAtIndex:8] : nil,
                             locArgs.count > 9 ? [locArgs objectAtIndex:9] : nil,
                             nil];
                }
            } else {
                title = [apsAlert stringForKey:@"title"];
            }
            alert = [apsAlert stringForKey:@"loc-key"];
            if (alert) alert = [WPUtil localizedStringIfPossible:alert];
            if (alert) {
                id locArgsId = [apsAlert arrayForKey:@"loc-args"];
                if (locArgsId) {
                    NSArray *locArgs = locArgsId;
                    alert = [NSString stringWithFormat:alert,
                             locArgs.count > 0 ? [locArgs objectAtIndex:0] : nil,
                             locArgs.count > 1 ? [locArgs objectAtIndex:1] : nil,
                             locArgs.count > 2 ? [locArgs objectAtIndex:2] : nil,
                             locArgs.count > 3 ? [locArgs objectAtIndex:3] : nil,
                             locArgs.count > 4 ? [locArgs objectAtIndex:4] : nil,
                             locArgs.count > 5 ? [locArgs objectAtIndex:5] : nil,
                             locArgs.count > 6 ? [locArgs objectAtIndex:6] : nil,
                             locArgs.count > 7 ? [locArgs objectAtIndex:7] : nil,
                             locArgs.count > 8 ? [locArgs objectAtIndex:8] : nil,
                             locArgs.count > 9 ? [locArgs objectAtIndex:9] : nil,
                             nil];
                }
            } else {
                alert = [apsAlert stringForKey:@"body"];
            }
            action = [apsAlert stringForKey:@"action-loc-key"];
            if (action) action = [WPUtil localizedStringIfPossible:action];
        } else if ([apsAlert isKindOfClass:[NSString class]]) {
            alert = (NSString *)apsAlert;
        }
        if (!title) title = [localizedInfoDictionary stringForKey:@"CFBundleDisplayName"];
        if (!title) title = [infoDictionary stringForKey:@"CFBundleDisplayName"];
        if (!title) title = [localizedInfoDictionary stringForKey:@"CFBundleName"];
        if (!title) title = [infoDictionary stringForKey:@"CFBundleName"];
        if (!title) title = [localizedInfoDictionary stringForKey:@"CFBundleExecutable"];
        if (!title) title = [infoDictionary stringForKey:@"CFBundleExecutable"];

        if (!action) {
            action = [WPUtil wpLocalizedString:@"VIEW" withDefault:@"View"];
        }
        if (alert) {
            UIAlertController *systemLikeAlert = [UIAlertController alertControllerWithTitle:title message:alert preferredStyle:UIAlertControllerStyleAlert];
            [systemLikeAlert addAction:[UIAlertAction actionWithTitle:[WPUtil wpLocalizedString:@"CLOSE" withDefault:@"Close"] style:UIAlertActionStyleCancel handler:nil]];
            [systemLikeAlert addAction:[UIAlertAction actionWithTitle:action style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [WonderPush handleNotificationOpened:notificationDictionary];
            }]];

            __block void (^presentBlock)(void) = ^{
                if ([UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), presentBlock);
                } else {
                    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:systemLikeAlert animated:YES completion:nil];
                    presentBlock = nil;
                }
            };
            dispatch_async(dispatch_get_main_queue(), presentBlock);
            return YES;
        }

    } else {

        WPLogDebug(@"handleNotification:withOriginalApplicationState: auto open");
        return [self handleNotificationOpened:notificationDictionary];

    }

    return NO;
}

+ (BOOL) handleNotificationOpened:(NSDictionary*)notificationDictionary
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotificationOpened:%@", notificationDictionary);

    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    conf.justOpenedNotification = notificationDictionary;

    NSDictionary *wonderpushData = [notificationDictionary dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
    WPLogDebug(@"Opened notification: %@", notificationDictionary);

    id campagnId      = [wonderpushData stringForKey:@"c"];
    id notificationId = [wonderpushData stringForKey:@"n"];
    NSMutableDictionary *notificationInformation = [NSMutableDictionary new];
    if (campagnId)      notificationInformation[@"campaignId"]     = campagnId;
    if (notificationId) notificationInformation[@"notificationId"] = notificationId;
    [self trackNotificationOpened:notificationInformation];

    id atOpenActions = [wonderpushData arrayForKey:@"actions"];
    if (atOpenActions) {
        for (id action in ((NSArray*)atOpenActions)) {
            if ([action isKindOfClass:[NSDictionary class]]) {
                [self executeAction:action onNotification:wonderpushData];
            }
        }
    }

    NSString *targetUrl = [wonderpushData stringForKey:WP_TARGET_URL_KEY];
    if (!targetUrl)
        targetUrl = WP_TARGET_URL_DEFAULT;
    WPLogDebug(@"handleNotificationOpened: targetUrl:%@", targetUrl);
    if ([targetUrl hasPrefix:WP_TARGET_URL_SDK_PREFIX]) {
        WPLogDebug(@"handleNotificationOpened: targetUrl has SDK prefix");
        if ([targetUrl isEqualToString:WP_TARGET_URL_BROADCAST]) {
            WPLogDebug(@"Broadcasting");
            [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_OPENED_BROADCAST object:nil userInfo:notificationDictionary];
        } else { //if ([targetUrl isEqualToString:WP_TARGET_URL_DEFAULT]) and the rest
            // noop!
        }
    } else {
        WPLogDebug(@"handleNotificationOpened: targetUrl will use openURL");
        // dispatch_async is necessary, before iOS 10, but dispatch_after 9ms is the minimum that seems necessary to avoid a 10s delay + possible crash with iOS 10...
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WPLogDebug(@"Opening url: %@", targetUrl);
            [self openURL:[NSURL URLWithString:targetUrl]];
        });
    }

    if ([self isDataNotification:notificationDictionary]) {
        WPLogDebug(@"handleNotificationOpened: data notification stopping");
        return NO;
    }
    NSString *type = [wonderpushData stringForKey:@"type"];
    if ([WP_PUSH_NOTIFICATION_SHOW_TEXT isEqualToString:type]) {
        WPLogDebug(@"handleNotificationOpened: showing text in-app");
        [self handleTextNotification:wonderpushData];
        return YES;
    } else if ([WP_PUSH_NOTIFICATION_SHOW_HTML isEqualToString:type]) {
        WPLogDebug(@"handleNotificationOpened: showing HTML in-app");
        [self handleHtmlNotification:wonderpushData];
        return YES;
    } else if ([WP_PUSH_NOTIFICATION_SHOW_URL isEqualToString:type]) {
        WPLogDebug(@"handleNotificationOpened: showing URL in-app");
        [self handleHtmlNotification:wonderpushData];
        return YES;
    }

    return NO;
}


#pragma mark - Session app open/close


+ (void) onInteractionLeaving:(BOOL)leaving
{
    if (![self isInitialized] || ![self hasUserConsent]) {
        // Do not remember last interaction altogether, so that a proper @APP_OPEN can be tracked once we get initialized
        return;
    }

    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    NSDate *lastInteractionDate = conf.lastInteractionDate;
    long long lastInteractionTs = lastInteractionDate ? (long long)([lastInteractionDate timeIntervalSince1970] * 1000) : 0;
    NSDate *lastAppOpenDate = conf.lastAppOpenDate;
    long long lastAppOpenTs = lastAppOpenDate ? (long long)([lastAppOpenDate timeIntervalSince1970] * 1000) : 0;
    NSDate *lastAppCloseDate = conf.lastAppCloseDate;
    long long lastAppCloseTs = lastAppCloseDate ? (long long)([lastAppCloseDate timeIntervalSince1970] * 1000) : 0;
    NSDate *lastReceivedNotificationDate = conf.lastReceivedNotificationDate;
    long long lastReceivedNotificationTs = lastReceivedNotificationDate ? (long long)([lastReceivedNotificationDate timeIntervalSince1970] * 1000) : LONG_LONG_MAX;
    NSDate *date = [NSDate date];
    long long now = [date timeIntervalSince1970] * 1000;

    BOOL shouldInjectAppOpen =
        now - lastInteractionTs >= DIFFERENT_SESSION_REGULAR_MIN_TIME_GAP
        || (
            [WPUtil hasBackgroundModeRemoteNotification]
            && lastReceivedNotificationTs > lastInteractionTs
            && now - lastInteractionTs >= DIFFERENT_SESSION_NOTIFICATION_MIN_TIME_GAP
        )
    ;

    if (leaving) {

        // Note the current time as the most accurate hint of last interaction
        conf.lastInteractionDate = [[NSDate alloc] initWithTimeIntervalSince1970:now / 1000.];

    } else {

        if (shouldInjectAppOpen) {
            // We will track a new app open event

            // We must first close the possibly still-open previous session
            if (lastAppCloseTs < lastAppOpenTs) {
                NSDictionary *openInfo = conf.lastAppOpenInfo;
                NSMutableDictionary *closeInfo = [[NSMutableDictionary alloc] initWithDictionary:openInfo];
                long long appCloseDate = lastInteractionTs;
                closeInfo[@"actionDate"] = [[NSNumber alloc] initWithLongLong:appCloseDate];
                closeInfo[@"openedTime"] = [[NSNumber alloc] initWithLongLong:appCloseDate - lastAppOpenTs];
                // [WonderPush trackInternalEvent:@"@APP_CLOSE" eventData:closeInfo customData:nil];
                conf.lastAppCloseDate = [[NSDate alloc] initWithTimeIntervalSince1970:appCloseDate / 1000.];
            }

            // Track the new app open event
            NSMutableDictionary *openInfo = [NSMutableDictionary new];
            // Add the elapsed time between the last received notification
            if ([WPUtil hasBackgroundModeRemoteNotification] && lastReceivedNotificationTs <= now) {
                openInfo[@"lastReceivedNotificationTime"] = [[NSNumber alloc] initWithLongLong:now - lastReceivedNotificationTs];
            }
            // Add the information of the clicked notification
            if (conf.justOpenedNotification && [conf.justOpenedNotification[@"_wp"] isKindOfClass:[NSDictionary class]]) {
                openInfo[@"campaignId"]     = conf.justOpenedNotification[@"_wp"][@"c"] ?: [NSNull null];
                openInfo[@"notificationId"] = conf.justOpenedNotification[@"_wp"][@"n"] ?: [NSNull null];
                conf.justOpenedNotification = nil;
            }
            [WonderPush trackInternalEvent:@"@APP_OPEN" eventData:openInfo customData:nil];
            conf.lastAppOpenDate = [[NSDate alloc] initWithTimeIntervalSince1970:now / 1000.];
            conf.lastAppOpenInfo = openInfo;
        }

        conf.lastInteractionDate = [[NSDate alloc] initWithTimeIntervalSince1970:now / 1000.];

    }
}

#pragma mark - Information mining

+ (void) updateInstallationCoreProperties
{
    [wonderPushAPI updateInstallationCoreProperties];
}

#pragma mark - REST API Access

+ (void) requestForUser:(NSString *)userId method:(NSString *)method resource:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    if (![WonderPush isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        if (handler) {
            handler(nil, [[NSError alloc] initWithDomain:WPErrorDomain
                                                    code:0
                                                userInfo:@{NSLocalizedDescriptionKey: @"The SDK is not initialized"}]);
        }
        return;
    }

    WPAPIClient *client = [WPAPIClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    parameters[@"timestamp"] = [NSString stringWithFormat:@"%lld", [WPUtil getServerDate]];
    request.userId = userId;
    request.method = method;
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;

    [client requestAuthenticated:request];
}

+ (void) post:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    if (![WonderPush isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        if (handler) {
            handler(nil, [[NSError alloc] initWithDomain:WPErrorDomain
                                                    code:0
                                                userInfo:@{NSLocalizedDescriptionKey: @"The SDK is not initialized"}]);
        }
        return;
    }

    WPAPIClient *client = [WPAPIClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    parameters[@"timestamp"] = [NSString stringWithFormat:@"%lld", [WPUtil getServerDate]];
    request.userId = [WPConfiguration sharedConfiguration].userId;
    request.method = @"POST";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;

    [client requestAuthenticated:request];
}

+ (void) get:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    if (![WonderPush isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        if (handler) {
            handler(nil, [[NSError alloc] initWithDomain:WPErrorDomain
                                                    code:0
                                                userInfo:@{NSLocalizedDescriptionKey: @"The SDK is not initialized"}]);
        }
        return;
    }

    WPAPIClient *client = [WPAPIClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    parameters[@"timestamp"] = [NSString stringWithFormat:@"%lld", [WPUtil getServerDate]];
    request.userId = [WPConfiguration sharedConfiguration].userId;
    request.method = @"GET";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestAuthenticated:request];
}

+ (void) delete:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    if (![WonderPush isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        if (handler) {
            handler(nil, [[NSError alloc] initWithDomain:WPErrorDomain
                                                    code:0
                                                userInfo:@{NSLocalizedDescriptionKey: @"The SDK is not initialized"}]);
        }
        return;
    }

    WPAPIClient *client = [WPAPIClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    parameters[@"timestamp"] = [NSString stringWithFormat:@"%lld", [WPUtil getServerDate]];
    request.userId = [WPConfiguration sharedConfiguration].userId;
    request.method = @"DELETE";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestAuthenticated:request];
}

+ (void) put:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    if (![WonderPush isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        if (handler) {
            handler(nil, [[NSError alloc] initWithDomain:WPErrorDomain
                                                    code:0
                                                userInfo:@{NSLocalizedDescriptionKey: @"The SDK is not initialized"}]);
        }
        return;
    }

    WPAPIClient *client = [WPAPIClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    parameters[@"timestamp"] = [NSString stringWithFormat:@"%lld", [WPUtil getServerDate]];
    request.userId = [WPConfiguration sharedConfiguration].userId;
    request.method = @"PUT";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestAuthenticated:request];
}

+ (void) postEventually:(NSString *)resource params:(id)params
{
    if (![WonderPush isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }

    WPAPIClient *client = [WPAPIClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    parameters[@"timestamp"] = [NSString stringWithFormat:@"%lld", [WPUtil getServerDate]];
    request.userId = [WPConfiguration sharedConfiguration].userId;
    request.method = @"POST";
    request.resource = resource;
    request.params = parameters;
    [client requestEventually:request];
}


#pragma mark - Language

+ (NSString *)languageCode
{
    if (_currentLanguageCode != nil) {
        return _currentLanguageCode;
    }
    NSArray *preferredLanguageCodes = [NSLocale preferredLanguages];
    return [self wonderpushLanguageCodeForLocaleLanguageCode:preferredLanguageCodes.count ? [preferredLanguageCodes objectAtIndex:0] : @"en"];
}

+ (void) setLanguageCode:(NSString *)languageCode
{
    if ([validLanguageCodes containsObject:languageCode]) {
        _currentLanguageCode = languageCode;
    }
}

+ (NSString *)wonderpushLanguageCodeForLocaleLanguageCode:(NSString *)localeLanguageCode
{
    NSString *code = [localeLanguageCode stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    if ([validLanguageCodes containsObject:code])
        return code;
    return @"en";
}

+ (CLLocation *)location
{
    return [wonderPushAPI location];
}

#pragma mark - Open URL
+ (BOOL) openURL:(NSURL *)URL
{
    NSURL *URLToOpen = URL;
    if (_delegate && [_delegate respondsToSelector:@selector(wonderPushWillOpenURL:)]) {
        URLToOpen = [_delegate wonderPushWillOpenURL:URLToOpen];
    }
    if (!URLToOpen) return NO;
    if (![[UIApplication sharedApplication] canOpenURL:URLToOpen]) return NO;
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:URLToOpen options:@{} completionHandler:nil];
        return YES;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[UIApplication sharedApplication] openURL:URLToOpen];
#pragma clang diagnostic pop
    }
}

+ (void) subscribeToNotifications
{
    [wonderPushAPI subscribeToNotifications];
}
+ (void) unsubscribeFromNotifications
{
    [wonderPushAPI unsubscribeFromNotifications];
}
+ (BOOL) isSubscribedToNotifications
{
    return [wonderPushAPI isSubscribedToNotifications];
}
+ (void) trackEvent:(NSString *)eventType attributes:(NSDictionary *)attributes
{
    [wonderPushAPI trackEvent:eventType attributes:attributes];
}
+ (void) putProperties:(NSDictionary *)properties
{
    [wonderPushAPI putProperties:properties];
}
+ (NSDictionary *) getProperties
{
    return [wonderPushAPI getProperties];
}
+ (void) clearEventsHistory
{
    return [wonderPushAPI clearEventsHistory];
}
+ (void) clearPreferences
{
    [wonderPushAPI clearPreferences];
}
+ (void) clearAllData
{
    [wonderPushAPI clearAllData];
}
+ (void) downloadAllData:(void(^)(NSData *data, NSError *error))completion
{
    [wonderPushAPI downloadAllData:completion];
}

@end
