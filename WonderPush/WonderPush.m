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
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <UserNotifications/UserNotifications.h>
#import <sys/utsname.h>
#import "WPUtil.h"
#import "WonderPush_private.h"
#import "WPAppDelegate.h"
#import "WPNotificationCenterDelegate.h"
#import "WPConfiguration.h"
#import "WPDialogButtonHandler.h"
#import "WPAlertViewDelegateBlock.h"
#import "WPAPIClient.h"
#import "PKAlertController.h"
#import "WPJsonUtil.h"
#import "WPLog.h"
#import "WPWebView.h"
#import "WPJsonSyncInstallationCustom.h"

static UIApplicationState _previousApplicationState = UIApplicationStateInactive;

static BOOL _isReady = NO;
static BOOL _isInitialized = NO;
static BOOL _isReachable = NO;

static BOOL _beforeInitializationUserIdSet = NO;
static NSString *_beforeInitializationUserId = nil;

static BOOL _userNotificationCenterDelegateInstalled = NO;

static NSString *_notificationFromAppLaunchCampaignId = nil;
static NSString *_notificationFromAppLaunchNotificationId = nil;


@implementation WonderPush

static NSString *_currentLanguageCode = nil;
static CLLocationManager *LocationManager = nil;
static NSArray *validLanguageCodes = nil;
static NSDictionary *deviceNamesByCode = nil;
static NSDictionary* gpsCapabilityByCode = nil;

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Initialize some constants
        validLanguageCodes = @[@"af", @"ar", @"be",
                               @"bg", @"bn", @"ca", @"cs", @"da", @"de", @"el", @"en", @"en_GB", @"en_US",
                               @"es", @"es_ES", @"es_MX", @"et", @"fa", @"fi", @"fr", @"fr_FR", @"fr_CA",
                               @"he", @"hi", @"hr", @"hu", @"id", @"is", @"it", @"ja", @"ko", @"lt", @"lv",
                               @"mk", @"ms", @"nb", @"nl", @"pa", @"pl", @"pt", @"pt_PT", @"pt_BR", @"ro",
                               @"ru", @"sk", @"sl", @"sq", @"sr", @"sv", @"sw", @"ta", @"th", @"tl", @"tr",
                               @"uk", @"vi", @"zh", @"zh_CN", @"zh_TW", @"zh_HK",
                               ];
        // Source: http://www.enterpriseios.com/wiki/iOS_Devices
        // Source: https://www.theiphonewiki.com/wiki/Models
        deviceNamesByCode = @{
                              @"iPhone1,1"   : @"iPhone 1G",
                              @"iPhone1,2"   : @"iPhone 3G",
                              @"iPhone2,1"   : @"iPhone 3GS",
                              @"iPhone3,1"   : @"iPhone 4",
                              @"iPhone3,2"   : @"iPhone 4",
                              @"iPhone3,3"   : @"Verizon iPhone 4",
                              @"iPhone4,1"   : @"iPhone 4S",
                              @"iPhone5,1"   : @"iPhone 5 (GSM)",
                              @"iPhone5,2"   : @"iPhone 5 (GSM+CDMA)",
                              @"iPhone5,3"   : @"iPhone 5c (GSM)",
                              @"iPhone5,4"   : @"iPhone 5c (Global)",
                              @"iPhone6,1"   : @"iPhone 5s (GSM)",
                              @"iPhone6,2"   : @"iPhone 5s (Global)",
                              @"iPhone7,1"   : @"iPhone 6 Plus",
                              @"iPhone7,2"   : @"iPhone 6",
                              @"iPhone8,1"   : @"iPhone 6S",
                              @"iPhone8,2"   : @"iPhone 6S Plus",
                              @"iPhone8,4"   : @"iPhone SE",
                              @"iPhone9,1"   : @"iPhone 7 (Global)",
                              @"iPhone9,3"   : @"iPhone 7 (GSM)",
                              @"iPhone9,2"   : @"iPhone 7 Plus (Global)",
                              @"iPhone9,4"   : @"iPhone 7 Plus (GSM)",
                              @"iPod1,1"     : @"iPod Touch 1G",
                              @"iPod2,1"     : @"iPod Touch 2G",
                              @"iPod3,1"     : @"iPod Touch 3G",
                              @"iPod4,1"     : @"iPod Touch 4G",
                              @"iPod5,1"     : @"iPod Touch 5G",
                              @"iPod7,1"     : @"iPod Touch 6",
                              @"iPad1,1"     : @"iPad",
                              @"iPad2,1"     : @"iPad 2 (WiFi)",
                              @"iPad2,2"     : @"iPad 2 (GSM)",
                              @"iPad2,3"     : @"iPad 2 (CDMA)",
                              @"iPad2,4"     : @"iPad 2 (WiFi)",
                              @"iPad2,5"     : @"iPad Mini (WiFi)",
                              @"iPad2,6"     : @"iPad Mini (GSM)",
                              @"iPad2,7"     : @"iPad Mini (GSM+CDMA)",
                              @"iPad3,1"     : @"iPad 3 (WiFi)",
                              @"iPad3,2"     : @"iPad 3 (GSM+CDMA)",
                              @"iPad3,3"     : @"iPad 3 (GSM)",
                              @"iPad3,4"     : @"iPad 4 (WiFi)",
                              @"iPad3,5"     : @"iPad 4 (GSM)",
                              @"iPad3,6"     : @"iPad 4 (GSM+CDMA)",
                              @"iPad4,1"     : @"iPad Air (WiFi)",
                              @"iPad4,2"     : @"iPad Air (GSM)",
                              @"iPad4,3"     : @"iPad Air",
                              @"iPad4,4"     : @"iPad Mini Retina (WiFi)",
                              @"iPad4,5"     : @"iPad Mini Retina (GSM)",
                              @"iPad4,6"     : @"iPad Mini 2G",
                              @"iPad4,7"     : @"iPad Mini 3 (WiFi)",
                              @"iPad4,8"     : @"iPad Mini 3 (Cellular)",
                              @"iPad4,9"     : @"iPad Mini 3 (China)",
                              @"iPad5,1"     : @"iPad Mini 4 (WiFi)",
                              @"iPad5,2"     : @"iPad Mini 4 (Cellular)",
                              @"iPad5,3"     : @"iPad Air 2 (WiFi)",
                              @"iPad5,4"     : @"iPad Air 2 (Cellular)",
                              @"iPad6,3"     : @"iPad Pro 9.7-inch (WiFi)",
                              @"iPad6,4"     : @"iPad Pro 9.7-inch (Cellular)",
                              @"iPad6,7"     : @"iPad Pro (WiFi)",
                              @"iPad6,8"     : @"iPad Pro (Cellular)",
                              @"AppleTV2,1"  : @"Apple TV 2G",
                              @"AppleTV3,1"  : @"Apple TV 3",
                              @"AppleTV3,2"  : @"Apple TV 3 (2013)",
                              @"AppleTV5,3"  : @"Apple TV 4G",
                              @"Watch1,1"    : @"Apple Watch 38mm",
                              @"Watch1,2"    : @"Apple Watch 42mm",
                              @"Watch2,3"    : @"Apple Watch Series 1 38mm",
                              @"Watch2,4"    : @"Apple Watch Series 1 42mm",
                              @"Watch2,6"    : @"Apple Watch Series 2 38mm",
                              @"Watch2,7"    : @"Apple Watch Series 2 42mm",
                              @"i386"        : @"Simulator",
                              @"x86_64"      : @"Simulator"
                              };
        gpsCapabilityByCode = @{
                                @"iPhone1,1"   : @NO,
                                @"iPhone1,2"   : @YES,
                                @"iPhone2,1"   : @YES,
                                @"iPhone3,1"   : @YES,
                                @"iPhone3,3"   : @YES,
                                @"iPhone4,1"   : @YES,
                                @"iPhone5,1"   : @YES,
                                @"iPhone5,2"   : @YES,
                                @"iPhone5,3"   : @YES,
                                @"iPhone5,4"   : @YES,
                                @"iPhone6,1"   : @YES,
                                @"iPhone6,2"   : @YES,
                                @"iPhone7,1"   : @YES,
                                @"iPhone7,2"   : @YES,
                                @"iPhone8,1"   : @YES,
                                @"iPhone8,2"   : @YES,
                                @"iPhone8,4"   : @YES,
                                @"iPhone9,1"   : @YES,
                                @"iPhone9,3"   : @YES,
                                @"iPhone9,2"   : @YES,
                                @"iPhone9,4"   : @YES,
                                @"iPod1,1"     : @NO,
                                @"iPod2,1"     : @NO,
                                @"iPod3,1"     : @NO,
                                @"iPod4,1"     : @NO,
                                @"iPod5,1"     : @NO,
                                @"iPod7,1"     : @NO,
                                @"iPad1,1"     : @NO,
                                @"iPad2,1"     : @NO,
                                @"iPad2,2"     : @YES,
                                @"iPad2,3"     : @YES,
                                @"iPad2,4"     : @NO,
                                @"iPad2,5"     : @NO,
                                @"iPad2,6"     : @YES,
                                @"iPad2,7"     : @YES,
                                @"iPad3,1"     : @NO,
                                @"iPad3,2"     : @YES,
                                @"iPad3,3"     : @YES,
                                @"iPad3,4"     : @NO,
                                @"iPad3,5"     : @YES,
                                @"iPad3,6"     : @YES,
                                @"iPad4,1"     : @NO,
                                @"iPad4,2"     : @YES,
                                @"iPad4,3"     : @YES,
                                @"iPad4,4"     : @YES,
                                @"iPad4,5"     : @YES,
                                @"iPad4,6"     : @YES,
                                @"iPad4,7"     : @YES,
                                @"iPad4,8"     : @YES,
                                @"iPad4,9"     : @YES,
                                @"iPad5,3"     : @NO,
                                @"iPad5,4"     : @YES,
                                @"iPad6,3"     : @YES,
                                @"iPad6,4"     : @YES,
                                @"iPad6,6"     : @YES,
                                @"iPad6,7"     : @YES,
                                @"AppleTV2,1"  : @NO,
                                @"AppleTV3,1"  : @NO,
                                @"AppleTV3,2"  : @NO,
                                @"AppleTV5,3"  : @NO,
                                @"Watch1,1"    : @NO,
                                @"Watch1,2"    : @NO,
                                @"Watch2,3"    : @NO,
                                @"Watch2,4"    : @NO,
                                @"Watch2,6"    : @NO,
                                @"Watch2,7"    : @NO,
                                @"i386"        : @NO,
                                @"x86_64"      : @NO
                                };
        // Initialize other variables
        LocationManager = [[CLLocationManager alloc] init];
    });
}

+ (void) setLogging:(BOOL)enable
{
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
}

+ (void) initForNewUser:(NSString *)userId
{
    WPLogDebug(@"initForNewUser:%@", userId);
    [self setIsReady:NO];
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    [configuration changeUserId:userId];
    [WPJsonSyncInstallationCustom forCurrentUser]; // ensures static initialization is done
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
}

+ (BOOL) getNotificationEnabled
{
    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    return sharedConfiguration.notificationEnabled;
}

+ (void) setNotificationEnabled:(BOOL)enabled
{
    WPLogDebug(@"setNotificationEnabled:%@", enabled ? @"YES" : @"NO");
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }

    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    BOOL previousValue = sharedConfiguration.notificationEnabled;
    sharedConfiguration.notificationEnabled = enabled;

    // Update the subscriptionStatus if it changed
    if (enabled != previousValue) {
        if (enabled) {
            [self updateInstallation:@{@"preferences":@{@"subscriptionStatus":@"optIn"}} shouldOverwrite:NO];
        } else {
            [self updateInstallation:@{@"preferences":@{@"subscriptionStatus":@"optOut"}} shouldOverwrite:NO];
        }
    }

    // Whether or not there is a change, register to push notifications if enabled
    if (enabled) {
        [self registerToPushNotifications];
    }
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


#pragma mark - Application delegate

+ (void) setupDelegateForApplication:(UIApplication *)application
{
    [WPAppDelegate setupDelegateForApplication:application];
}

+ (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (![self isInitialized]) return NO;
    if ([WPAppDelegate isAlreadyRunning]) return NO;

    if ([self getNotificationEnabled]) {
        [self registerToPushNotifications];
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
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    [WonderPush handleNotification:userInfo];
    if (completionHandler) {
        completionHandler(UIBackgroundFetchResultNewData);
    }
}

+ (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    [WonderPush handleNotification:notification.userInfo withOriginalApplicationState:UIApplicationStateInactive];
}

+ (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    [self handleNotification:userInfo];
}

+ (void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    NSString *newToken = [deviceToken description];
    [WonderPush setDeviceToken:newToken];
}

+ (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    WPLogDebug(@"Failed to register to push notifications: %@", error);
    [WonderPush setDeviceToken:nil];
}

+ (void) applicationDidBecomeActive:(UIApplication *)application;
{
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    BOOL comesBackFromTemporaryInactive = _previousApplicationState == UIApplicationStateActive;
    _previousApplicationState = UIApplicationStateActive;

    // Show any queued notifications
    UIApplicationState originalApplicationState = comesBackFromTemporaryInactive ? UIApplicationStateActive : UIApplicationStateInactive;
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    NSArray *queuedNotifications = [configuration getQueuedNotifications];
    for (NSDictionary *queuedNotification in queuedNotifications) {
        if (![queuedNotification isKindOfClass:[NSDictionary class]]) continue;
        [self handleNotification:queuedNotification withOriginalApplicationState:originalApplicationState];
    }
    [configuration clearQueuedNotifications];

    [self onInteraction];
}

+ (void) applicationDidEnterBackground:(UIApplication *)application
{
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    _previousApplicationState = UIApplicationStateBackground;

    [WPJsonSyncInstallationCustom flush];

    // Send queued notifications as LocalNotifications
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    NSArray *queuedNotifications = [configuration getQueuedNotifications];
    for (NSDictionary *userInfo in queuedNotifications) {
        if (![userInfo isKindOfClass:[NSDictionary class]]) continue;
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        if (![WPUtil currentApplicationIsInForeground]) {
            NSDictionary *aps = [userInfo dictionaryForKey:@"aps"];
            NSDictionary *alertDict = [aps dictionaryForKey:@"alert"];
            NSString *alert = alertDict ? [alertDict stringForKey:@"body"] : [aps stringForKey:@"alert"];
            notification.alertBody = alert;
            notification.soundName = [aps stringForKey:@"sound"];
            notification.userInfo = userInfo;
            [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        }
    }
    [configuration clearQueuedNotifications];

    [self onInteraction];
}


#pragma mark - UserNotificationCenter delegate

+ (void) setupDelegateForUserNotificationCenter
{
    if (!_userNotificationCenterDelegateInstalled) {
        WPLogDebug(@"Setting the notification center delegate");
        [WPNotificationCenterDelegate setupDelegateForNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]];
    }
}

+ (void) setUserNotificationCenterDelegateInstalled:(BOOL)enabled
{
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

+ (void) userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler
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
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.installationId;
}

+ (NSString *) deviceId
{
    return [WPUtil deviceIdentifier];
}

+ (NSString *) pushToken
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.deviceToken;
}

+ (NSString *) accessToken
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.accessToken;
}


#pragma mark - Installation data and events

+ (NSDictionary *) getInstallationCustomProperties
{
    [self onInteraction];
    return [[WPJsonSyncInstallationCustom forCurrentUser].sdkState copy];
}

+ (void) updateInstallation:(NSDictionary *)properties shouldOverwrite:(BOOL)overwrite
{
    if (!overwrite && (![properties isKindOfClass:[NSDictionary class]] || !properties.count)) return;
    NSString *installationEndPoint = @"/installation";
    [self postEventually:installationEndPoint params:@{@"body":properties, @"overwrite":[NSNumber numberWithBool:overwrite]}];
}

+ (void) putInstallationCustomProperties:(NSDictionary *)customProperties
{
    WPLogDebug(@"putInstallationCustomProperties:%@", customProperties);
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }
    [self onInteraction];
    [[WPJsonSyncInstallationCustom forCurrentUser] put:customProperties];
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
    NSDictionary *wpData = [userInfo dictionaryForKey:WP_PUSH_NOTIFICATION_KEY];
    id receipt        = [wpData nullsafeObjectForKey:@"receipt"];
    if (receipt && [[receipt class] isEqual:[@YES class]] && [receipt isEqual:@NO]) return; // lengthy but warning-free test for `receipt == @NO`, both properly distinguishes 0 from @NO, whereas `[receipt isEqual:@NO]` alone does not
    id campagnId      = [wpData stringForKey:@"c"];
    id notificationId = [wpData stringForKey:@"n"];
    NSMutableDictionary *notificationInformation = [NSMutableDictionary new];
    if (campagnId)      notificationInformation[@"campaignId"]     = campagnId;
    if (notificationId) notificationInformation[@"notificationId"] = notificationId;
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    conf.lastReceivedNotificationDate = [NSDate date];
    conf.lastReceivedNotification = notificationInformation;
    [self trackInternalEvent:@"@NOTIFICATION_RECEIVED" eventData:notificationInformation customData:nil];
}

+ (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    if ([type characterAtIndex:0] != '@') {
        @throw [NSException exceptionWithName:@"illegal argument" reason:@"This method must only be called for internal events, starting with an '@'" userInfo:nil];
    }

    [self trackEvent:type eventData:data customData:customData];
}

+ (void) trackEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    if (![self isInitialized]) {
        WPLog(@"%@: The SDK is not initialized.", NSStringFromSelector(_cmd));
        return;
    }

    if (![type isKindOfClass:[NSString class]]) return;
    NSString *eventEndPoint = @"/events";
    long long date = [WPUtil getServerDate];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{@"type": type,
                                                                                    @"actionDate": [NSNumber numberWithLongLong:date]}];

    if ([data isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in data) {
            [params setValue:[data objectForKey:key] forKey:key];
        }
    }

    if ([customData isKindOfClass:[NSDictionary class]]) {
        [params setValue:customData forKey:@"custom"];
    }

    CLLocation *location = [self location];
    if (location != nil) {
        params[@"location"] = @{@"lat": [NSNumber numberWithDouble:location.coordinate.latitude],
                                @"lon": [NSNumber numberWithDouble:location.coordinate.longitude]};
    }

    [self postEventually:eventEndPoint params:@{@"body":params}];

}

+ (void) trackEvent:(NSString*)type
{
    WPLogDebug(@"trackEvent:%@", type);
    [self trackEvent:type eventData:nil customData:nil];
    [self onInteraction];
}

+ (void) trackEvent:(NSString*)type withData:(NSDictionary *)data
{
    WPLogDebug(@"trackEvent:%@ withData:%@", type, data);
    [self trackEvent:type eventData:nil customData:data];
    [self onInteraction];
}


#pragma mark - push notification types handling

// We need to keep a reference on the DialogButtonHandler as the UIAlertView just keep a weak reference.
// We can only have one dialog on screen so having only one reference is no problem
static WPDialogButtonHandler *buttonHandler = nil;
static void(^presentBlock)(void) = nil;

+ (void) resetButtonHandler
{
    buttonHandler = nil;
}

+ (void) handleTextNotification:(NSDictionary *)wonderPushData
{
    if (buttonHandler != nil) {
        // we currently support only one dialog at a time
        return;
    }

    UIAlertView *dialog = [[UIAlertView alloc] initWithTitle:[wonderPushData stringForKey:@"title"] message:[wonderPushData stringForKey:@"message"] delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
    NSArray *buttons = [wonderPushData arrayForKey:@"buttons"];
    buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.notificationConfiguration = wonderPushData;
    buttonHandler.buttonConfiguration = buttons;
    dialog.delegate = buttonHandler;
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        for (NSDictionary *button in buttons) {
            if (![button isKindOfClass:[NSDictionary class]]) continue;
            [dialog addButtonWithTitle:[button stringForKey:@"label"]];
        }
    } else {
        [dialog addButtonWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL];
    }
    [dialog show];
}

+ (void) handleHtmlNotification:(NSDictionary*)wonderPushData
{
    if (buttonHandler != nil) {
        // we currently support only one dialog at a time
        return;
    }
    WPWebView *view = [WPWebView new];
    // NSString *title = [wonderPushData stringForKey:@"title"];
    NSString *message = [wonderPushData stringForKey:@"message"];
    NSString *url = [wonderPushData valueForKey:@"url"];
    if (message != nil) {
        [view loadHTMLString:message baseURL:nil];
    } else if (url != nil) {
        [view loadRequest:[[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]]];
    } else {
        WPLogDebug(@"Error the link / url provided is null");
        return;
    }

    NSArray *buttons = [wonderPushData objectForKey:@"buttons"];
    buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.buttonConfiguration = buttons;
    buttonHandler.notificationConfiguration = wonderPushData;
    NSMutableArray *alertButtons = [[NSMutableArray alloc] initWithCapacity:MIN(1, [buttons count])];
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        int i = -1;
        for (NSDictionary *button in buttons) {
            ++i;
            [alertButtons addObject:[PKAlertAction actionWithTitle:[button valueForKey:@"label"] handler:^(PKAlertAction *action, BOOL closed) {
                if (!closed) {
                    [buttonHandler alertView:nil clickedButtonAtIndex:i];
                } else {
                    [buttonHandler alertView:nil clickedButtonAtIndex:-1];
                }
                buttonHandler = nil;
            }]];
        }
    } else {
        [alertButtons addObject:[PKAlertAction actionWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL handler:^(PKAlertAction *action, BOOL closed) {
            if (!closed) {
                [buttonHandler alertView:nil clickedButtonAtIndex:0];
            } else {
                [buttonHandler alertView:nil clickedButtonAtIndex:-1];
            }
            buttonHandler = nil;
        }]];
    }

    PKAlertViewController *alert = [PKAlertViewController alertControllerWithConfigurationBlock:^(PKAlertControllerConfiguration *configuration) {
        // configuration.title = title; // TODO support title in addition to UIWebView
        configuration.customView = view;
        configuration.preferredStyle = PKAlertControllerStyleAlert;
        configuration.presentationTransitionStyle = PKAlertControllerPresentationTransitionStyleFocusIn;
        configuration.dismissTransitionStyle = PKAlertControllerDismissTransitionStyleZoomOut;
        configuration.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
        configuration.scrollViewTransparentEdgeEnabled = NO;
        [configuration addActions:alertButtons];
    }];

    presentBlock = ^{
        if ([UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), presentBlock);
        } else {
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            presentBlock = nil;
        }
    };
    dispatch_async(dispatch_get_main_queue(), presentBlock);
}

+ (void) handleMapNotification:(NSDictionary*)wonderPushData
{
    // We currently support only one dialog at a time
    if (buttonHandler != nil) return;

    // NSString *title = [wonderPushData stringForKey:@"title"];
    // NSString *message = [wonderPushData stringForKey:@"message"];
    NSDictionary *mapData = [wonderPushData dictionaryForKey:@"map"] ?: @{};
    NSDictionary *place = [mapData dictionaryForKey:@"place"] ?: @{};
    NSDictionary *point = [place dictionaryForKey:@"point"] ?: @{};
    NSNumber *lat = [point numberForKey:@"lat"];
    NSNumber *lon = [point numberForKey:@"lon"];
    NSNumber *zoom = [point numberForKey:@"zoom"];
    if (!lat || !lon || !zoom) return;

    NSString *staticMapUrl = [NSString stringWithFormat:@"http://maps.google.com/maps/api/staticmap?markers=color:red|%f,%f&zoom=%ld&size=290x290&sensor=true",
                              [lat doubleValue], [lon doubleValue], (long)[zoom integerValue]];

    NSURL *mapUrl = [NSURL URLWithString:[staticMapUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:mapUrl]];

    UIImageView * view = [[UIImageView alloc] initWithImage:image];

    NSArray *buttons = [wonderPushData objectForKey:@"buttons"];
    buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.buttonConfiguration = buttons;
    buttonHandler.notificationConfiguration = wonderPushData;
    NSMutableArray *alertButtons = [[NSMutableArray alloc] initWithCapacity:MIN(1, [buttons count])];
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        int i = -1;
        for (NSDictionary *button in buttons) {
            ++i;
            [alertButtons addObject:[PKAlertAction actionWithTitle:[button valueForKey:@"label"] handler:^(PKAlertAction *action, BOOL closed) {
                if (!closed) {
                    [buttonHandler alertView:nil clickedButtonAtIndex:i];
                } else {
                    [buttonHandler alertView:nil clickedButtonAtIndex:-1];
                }
                buttonHandler = nil;
            }]];
        }
    } else {
        [alertButtons addObject:[PKAlertAction actionWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL handler:^(PKAlertAction *action, BOOL closed) {
            if (!closed) {
                [buttonHandler alertView:nil clickedButtonAtIndex:0];
            } else {
                [buttonHandler alertView:nil clickedButtonAtIndex:-1];
            }
            buttonHandler = nil;
        }]];
    }

    PKAlertViewController *alert = [PKAlertViewController alertControllerWithConfigurationBlock:^(PKAlertControllerConfiguration *configuration) {
        // configuration.title = title; // TODO support title in addition to UIImageView
        // configuration.message = message; // TODO support title in addition to UIImageView
        configuration.customView = (UIView<PKAlertViewLayoutAdapter> *) view;
        configuration.preferredStyle = PKAlertControllerStyleAlert;
        configuration.presentationTransitionStyle = PKAlertControllerPresentationTransitionStyleFocusIn;
        configuration.dismissTransitionStyle = PKAlertControllerDismissTransitionStyleZoomOut;
        configuration.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
        configuration.scrollViewTransparentEdgeEnabled = NO;
        [configuration addActions:alertButtons];
    }];

    presentBlock = ^{
        if ([UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), presentBlock);
        } else {
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            presentBlock = nil;
        }
    };
    dispatch_async(dispatch_get_main_queue(), presentBlock);
}

+ (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *)notification
{
    WPLogDebug(@"Running action %@", action);
    NSString *type = [action stringForKey:@"type"];

    if ([WP_ACTION_TRACK isEqualToString:type]) {

        NSDictionary *event = [action dictionaryForKey:@"event"] ?: @{};
        NSString *type = [event stringForKey:@"type"];
        if (!type) return;
        NSDictionary *custom = [event dictionaryForKey:@"custom"];
        [WonderPush trackEvent:type
                     eventData:@{@"campaignId": notification[@"c"] ?: [NSNull null],
                                 @"notificationId": notification[@"n"] ?: [NSNull null]}
                    customData:custom];

    } else if ([WP_ACTION_UPDATE_INSTALLATION isEqualToString:type]) {

        NSDictionary *custom = [([action dictionaryForKey:@"installation"] ?: action) dictionaryForKey:@"custom"];
        if (!custom) return;
        NSNumber *appliedServerSide = [action numberForKey:@"appliedServerSide"];
        if ([appliedServerSide isEqual:@YES]) {
            WPLogDebug(@"Received server custom properties diff: %@", custom);
            [[WPJsonSyncInstallationCustom forCurrentUser] receiveDiff:custom];
        } else {
            WPLogDebug(@"Putting custom properties diff: %@", custom);
            [[WPJsonSyncInstallationCustom forCurrentUser] put:custom];
        }

    } else if ([WP_ACTION_RESYNC_INSTALLATION isEqualToString:type]) {

        WPConfiguration *conf = [WPConfiguration sharedConfiguration];
        void (^cont)(NSDictionary *action) = ^(NSDictionary *action){
            WPLogDebug(@"Running enriched action %@", action);
            NSDictionary *installation = [action dictionaryForKey:@"installation"] ?: @{};
            NSDictionary *custom = [installation dictionaryForKey:@"custom"] ?: @{};
            NSNumber *reset = [action numberForKey:@"reset"];
            NSNumber *force = [action numberForKey:@"force"];

            // Take or reset custom
            if ([reset isEqual:@YES]) {
                [[WPJsonSyncInstallationCustom forCurrentUser] receiveState:custom resetSdkState:[force isEqual:@YES]];
            } else {
                [[WPJsonSyncInstallationCustom forCurrentUser] receiveServerState:custom];
            }

            // Refresh core properties
            conf.cachedInstallationCoreProperties = @{};
            [WonderPush updateInstallationCoreProperties];

            // Refresh push token
            id oldDeviceToken = conf.deviceToken;
            conf.deviceToken = nil;
            [WonderPush setDeviceToken:oldDeviceToken];

            // Refresh preferences
            if (conf.notificationEnabled) {
                [self updateInstallation:@{@"preferences":@{@"subscriptionStatus":@"optIn"}} shouldOverwrite:NO];
            } else {
                [self updateInstallation:@{@"preferences":@{@"subscriptionStatus":@"optOut"}} shouldOverwrite:NO];
            }
        };

        NSDictionary *installation = [action dictionaryForKey:@"installation"];
        if (installation) {
            cont(action);
        } else {

            WPLogDebug(@"Fetching installation for action %@", type);
            [WonderPush get:@"/installation" params:nil handler:^(WPResponse *response, NSError *error) {
                if (error) {
                    WPLog(@"Failed to fetch installation for running action %@: %@", action, error);
                    return;
                }
                if (![response.object isKindOfClass:[NSDictionary class]]) {
                    WPLog(@"Failed to fetch installation for running action %@, got: %@", action, response.object);
                    return;
                }
                NSMutableDictionary *installation = [(NSDictionary *)response.object mutableCopy];
                // Filter other fields starting with _ like _serverTime and _serverTook
                [installation removeObjectsForKeys:[installation.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                    return [evaluatedObject isKindOfClass:[NSString class]] && [(NSString*)evaluatedObject hasPrefix:@"_"];
                }]]];
                NSMutableDictionary *actionFilled = [[NSMutableDictionary alloc] initWithDictionary:action];
                actionFilled[@"installation"] = [NSDictionary dictionaryWithDictionary:installation];
                cont(actionFilled);
                // We added async processing, we need to ensure that we flush it too, especially in case we're running receiveActions in the background
                [WPJsonSyncInstallationCustom flush];
            }];

        }

    } else if ([WP_ACTION_RATING isEqualToString:type]) {

        NSString *itunesAppId = [[NSBundle mainBundle] objectForInfoDictionaryKey:WP_ITUNES_APP_ID];
        if (itunesAppId != nil) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:ITUNES_APP_URL_FORMAT, itunesAppId]]];
        }

    } else  if ([WP_ACTION_METHOD_CALL isEqualToString:type]) {

        NSString *methodName = [action stringForKey:@"method"];
        id methodParameter = [action nullsafeObjectForKey:@"methodArg"];
        NSDictionary *parameters = @{WP_REGISTERED_CALLBACK_PARAMETER_KEY: methodParameter ?: [NSNull null]};
        [[NSNotificationCenter defaultCenter] postNotificationName:methodName object:self userInfo:parameters];

    } else if ([WP_ACTION_LINK isEqualToString:type]) {

        NSString *url = [action stringForKey:@"url"];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];

    } else if ([WP_ACTION_MAP_OPEN isEqualToString:type]) {

        NSDictionary *mapData = [notification dictionaryForKey:@"map"] ?: @{};
        NSDictionary *place = [mapData dictionaryForKey:@"place"] ?: @{};
        NSDictionary *point = [place dictionaryForKey:@"point"] ?: @{};
        NSNumber *lat = [point numberForKey:@"lat"];
        NSNumber *lon = [point numberForKey:@"lon"];
        if (!lat || !lon) return;
        NSString *url = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%f,%f", [lat doubleValue], [lon doubleValue]];
        WPLogDebug(@"url: %@", url);
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];

    } else if ([WP_ACTION__DUMP_STATE isEqualToString:type]) {

        NSDictionary *stateDump = [[WPConfiguration sharedConfiguration] dumpState] ?: @{};
        WPLog(@"STATE DUMP: %@", stateDump);
        [WonderPush trackInternalEvent:@"@DEBUG_DUMP_STATE"
                             eventData:nil
                            customData:@{@"ignore_sdkStateDump": stateDump}];

    } else {
        WPLogDebug(@"Unhandled action type %@", type);
    }
}

+ (void) setDeviceToken:(NSString *)deviceToken
{
    if (deviceToken) {
        deviceToken = [deviceToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
        deviceToken = [deviceToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    }

    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    NSString *oldDeviceToken = [sharedConfiguration deviceToken];

    if (
        // New device token
        (deviceToken == nil && oldDeviceToken != nil) || (deviceToken != nil && oldDeviceToken == nil)
        || (deviceToken != nil && oldDeviceToken != nil && ![deviceToken isEqualToString:oldDeviceToken])
        // Last associated with another userId?
        || (sharedConfiguration.userId == nil && sharedConfiguration.deviceTokenAssociatedToUserId != nil)
        || (sharedConfiguration.userId != nil && ![sharedConfiguration.userId isEqualToString:sharedConfiguration.deviceTokenAssociatedToUserId])
        // Last associated with another access token?
        || (sharedConfiguration.accessToken == nil && sharedConfiguration.cachedDeviceTokenAccessToken != nil)
        || (sharedConfiguration.accessToken != nil && ![sharedConfiguration.accessToken isEqualToString:sharedConfiguration.cachedDeviceTokenAccessToken])
    ) {
        [sharedConfiguration setDeviceToken:deviceToken];
        [sharedConfiguration setDeviceTokenAssociatedToUserId:sharedConfiguration.userId];
        [sharedConfiguration setCachedDeviceTokenDate:[NSDate date]];
        [sharedConfiguration setCachedDeviceTokenAccessToken:sharedConfiguration.accessToken];
        [self updateInstallation:@{@"pushToken": @{@"data": deviceToken ?: [NSNull null]}}
                 shouldOverwrite:NO];
    }
}

+ (BOOL) hasAcceptedVisibleNotifications
{
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
        return [[UIApplication sharedApplication] currentUserNotificationSettings].types != 0;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != 0;
#pragma clang diagnostic pop
    }
}

+ (BOOL) isRegisteredForRemoteNotifications
{
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        return [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != 0;
#pragma clang diagnostic pop
    }
}

+ (void) refreshDeviceTokenIfPossible
{
    if (![self hasAcceptedVisibleNotifications]) return;
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)]) {
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:[[UIApplication sharedApplication] enabledRemoteNotificationTypes]];
#pragma clang diagnostic pop
    }
}

+ (void) registerToPushNotifications
{
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
#pragma clang diagnostic pop
    }
}

+ (BOOL) handleNotification:(NSDictionary*)notificationDictionary
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotification:%@", notificationDictionary);

    UIApplicationState appState = [UIApplication sharedApplication].applicationState;

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
            [WonderPush trackNotificationReceived:notificationDictionary];

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
    }

    if (appState == UIApplicationStateBackground) {
        // The application won't run long enough to perform any scheduled updates of custom properties to the server
        // that may have been asked by receiveActions, flush now.
        // If we had no such modifications, this is still an opportunity to flush any interrupted calls.
        [WPJsonSyncInstallationCustom flush];
        return YES;
    }

    if (appState == UIApplicationStateInactive) {
        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        [configuration addToQueuedNotifications:notificationDictionary];
        return YES;
    }

    return [self handleNotification:notificationDictionary withOriginalApplicationState:appState];
}

+ (BOOL) handleNotification:(NSDictionary*)notificationDictionary withOriginalApplicationState:(UIApplicationState)applicationState
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotification:%@ withOriginalApplicationState:%d", notificationDictionary, applicationState);

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
            UIAlertView *systemLikeAlert = [[UIAlertView alloc] initWithTitle:title
                                                                      message:alert
                                                                     delegate:nil
                                                            cancelButtonTitle:[WPUtil wpLocalizedString:@"CLOSE" withDefault:@"Close"]
                                                            otherButtonTitles:action, nil];
            [WPAlertViewDelegateBlock forAlert:systemLikeAlert withBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    [WonderPush handleNotificationOpened:notificationDictionary];
                }
            }];
            [systemLikeAlert show];
            return YES;
        }

    } else {

        return [self handleNotificationOpened:notificationDictionary];

    }

    return NO;
}

+ (BOOL) handleNotificationOpened:(NSDictionary*)notificationDictionary
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;

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
    if ([targetUrl hasPrefix:WP_TARGET_URL_SDK_PREFIX]) {
        if ([targetUrl isEqualToString:WP_TARGET_URL_BROADCAST]) {
            WPLogDebug(@"Broadcasting");
            [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_OPENED_BROADCAST object:nil userInfo:notificationDictionary];
        } else { //if ([targetUrl isEqualToString:WP_TARGET_URL_DEFAULT]) and the rest
            // noop!
        }
    } else {
        // dispatch_async is necessary, before iOS 10, but dispatch_after 9ms is the minimum that seems necessary to avoid a 10s delay + possible crash with iOS 10...
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WPLogDebug(@"Opening url: %@", targetUrl);
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:targetUrl]];
        });
    }

    if ([self isDataNotification:notificationDictionary]) {
        return NO;
    }
    NSString *type = [wonderpushData stringForKey:@"type"];
    if ([WP_PUSH_NOTIFICATION_SHOW_TEXT isEqualToString:type]) {
        [self handleTextNotification:wonderpushData];
        return YES;
    } else if ([WP_PUSH_NOTIFICATION_SHOW_HTML isEqualToString:type]) {
        [self handleHtmlNotification:wonderpushData];
        return YES;
    } else if ([WP_PUSH_NOTIFICATION_SHOW_URL isEqualToString:type]) {
        [self handleHtmlNotification:wonderpushData];
        return YES;
    } else if ([WP_PUSH_NOTIFICATION_SHOW_MAP isEqualToString:type]) {
        [self handleMapNotification:wonderpushData];
        return YES;
    }

    return NO;
}


#pragma mark - Session app open/close


+ (void) onInteraction
{
    if (![self isInitialized]) {
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

    if (
        now - lastInteractionTs >= DIFFERENT_SESSION_REGULAR_MIN_TIME_GAP
        || (
            [WPUtil hasBackgroundModeRemoteNotification]
            && lastReceivedNotificationTs > lastInteractionTs
            && now - lastInteractionTs >= DIFFERENT_SESSION_NOTIFICATION_MIN_TIME_GAP
        )
    ) {
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

#pragma mark - Information mining

+ (void) updateInstallationCoreProperties
{
    NSNull *null = [NSNull null];
    NSDictionary *apple = @{@"apsEnvironment": [WPUtil getEntitlement:@"aps-environment"] ?: null,
                            @"appId": [WPUtil getEntitlement:@"application-identifier"] ?: null,
                            @"backgroundModes": [WPUtil getBackgroundModes] ?: null
                            };
    NSDictionary *application = @{@"version" : [self getVersionString] ?: null,
                                  @"sdkVersion": [self getSDKVersionNumber] ?: null,
                                  @"apple": apple ?: null
                                  };

    NSDictionary *configuration = @{@"timeZone": [self getTimezone] ?: null,
                                    @"carrier": [self getCarrierName] ?: null,
                                    @"country": [self getCountry] ?: null,
                                    @"currency": [self getCurrency] ?: null,
                                    @"locale": [self getLocale] ?: null};

    NSDictionary *capabilities = @{@"telephony": [NSNumber numberWithBool:[self getTelephonySupported]] ?: null,
                                   @"telephonyGsm": [NSNumber numberWithBool:[self getTelephonyGSMSupported]] ?: null,
                                   @"telephonyCdma": [NSNumber numberWithBool:[self getTelephoneCDMASupported]] ?: null,
                                   @"wifi": @YES, // all have wifi otherwise how did we install the app
                                   @"wifiDirect": @NO, // not supported by Apple
                                   @"gps": [NSNumber numberWithBool:[self getGPSSupported]] ?: null,
                                   @"networkLocation": @YES,
                                   @"microphone": [NSNumber numberWithBool:[self getMicrophoneSupported]] ?: null,
                                   @"sensorAccelerometer":@YES,
                                   @"sensorBarometer": @NO,
                                   @"sensorCompass": [NSNumber numberWithBool:[self getCompassSupported]] ?: null,
                                   @"sensorGyroscope": [NSNumber numberWithBool:[self getGyroscopeSupported]] ?: null,
                                   @"sensorLight": @YES,
                                   @"sensorProximity": [NSNumber numberWithBool:[self getProximitySensorSupported]] ?: null,
                                   @"sensorStepDetector": @NO,
                                   @"touchscreen": @YES,
                                   @"touchscreenTwoFingers": @YES,
                                   @"touchscreenDistinct": @YES,
                                   @"touchscreenFullHand": @YES,
                                   @"figerprintScanner":[NSNumber numberWithBool:[self getFingerprintScannerSupported]] ?: null
                                   };

    CGRect screenSize = [self getScreenSize];
    NSDictionary *device = @{@"id": [WPUtil deviceIdentifier] ?: null,
                             @"platform": @"iOS",
                             @"osVersion": [self getOsVersion] ?: null,
                             @"brand": @"Apple",
                             @"model": [self getDeviceModel] ?: null,
                             @"name": [self getDeviceName] ?: null,
                             @"screenWidth": [NSNumber numberWithInt:(int)screenSize.size.width] ?: null,
                             @"screenHeight": [NSNumber numberWithInt:(int)screenSize.size.height] ?: null,
                             @"screenDensity": [NSNumber numberWithInt:(int)[self getScreenDensity]] ?: null,
                             @"configuration": configuration,
                             @"capabilities": capabilities,
                             };

    NSDictionary *properties = @{@"application": application,
                                 @"device": device
                                 };

    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    NSDictionary *oldProperties = sharedConfiguration.cachedInstallationCoreProperties;
    NSDate *oldPropertiesDate = sharedConfiguration.cachedInstallationCorePropertiesDate;
    NSString *oldPropertiesAccessToken = sharedConfiguration.cachedInstallationCorePropertiesAccessToken;
    if (![oldProperties isKindOfClass:[NSDictionary class]]
        || ![oldPropertiesDate isKindOfClass:[NSDate class]]
        || ![oldPropertiesAccessToken isKindOfClass:[NSString class]]
        || ![oldProperties isEqualToDictionary:properties]
        || ![oldPropertiesAccessToken isEqualToString:sharedConfiguration.accessToken]
    ) {
        [sharedConfiguration setCachedInstallationCoreProperties:properties];
        [sharedConfiguration setCachedInstallationCorePropertiesDate: [NSDate date]];
        [sharedConfiguration setCachedInstallationCorePropertiesAccessToken:sharedConfiguration.accessToken];
        [self updateInstallation:properties shouldOverwrite:NO];
    }
}

+ (NSString *) getSDKVersionNumber
{
    NSString *result;
    result = SDK_VERSION;
    return result;
}

+ (BOOL) getProximitySensorSupported
{
    UIDevice *device = [UIDevice currentDevice];
    if (device) {
        device.proximityMonitoringEnabled = YES;
        if (device.proximityMonitoringEnabled == YES) {
            device.proximityMonitoringEnabled = NO;
            return YES;
        }
    }
    return NO;
}

+ (BOOL) getGyroscopeSupported
{
#ifdef __IPHONE_4_0
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    return motionManager.gyroAvailable;
#else
    return NO;
#endif
}

+ (BOOL) getCompassSupported
{
    BOOL compassAvailable = NO;

#ifdef __IPHONE_3_0
	compassAvailable = [CLLocationManager headingAvailable];
#else
	CLLocationManager *cl = [[CLLocationManager alloc] init];
	compassAvailable = cl.headingAvailable;
#endif
    return compassAvailable;
}

+ (BOOL) getMicrophoneSupported
{
    NSArray *availableInputs = [[AVAudioSession sharedInstance] availableInputs];
    if (availableInputs) {
        for (AVAudioSessionPortDescription *port in availableInputs) {
            if (!port) continue;
            if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic] ||
                [port.portType isEqualToString:AVAudioSessionPortHeadsetMic]
            ) {
                return YES;
            }
        }
    }
    return NO;
}

+ (BOOL) getGPSSupported
{
    struct utsname systemInfo;

    uname(&systemInfo);

    NSString* code = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];

    BOOL gpsCapability = NO;
    id kbValue = [gpsCapabilityByCode numberForKey:code];
    if (kbValue != nil) {
        gpsCapability = [kbValue boolValue];
    } else {
        // Not found on database. At least guess main device type from string contents:

        if ([code rangeOfString:@"iPod"].location != NSNotFound) {
            gpsCapability = NO;
        } else if([code rangeOfString:@"iPad"].location != NSNotFound) {
            gpsCapability = YES; // this is not sure but let's assume the future will tend to that
        } else if([code rangeOfString:@"iPhone"].location != NSNotFound){
            gpsCapability = YES;
        } else {
            gpsCapability = NO;
        }
    }

    return gpsCapability;
}

+ (BOOL) getTelephoneCDMASupported
{
    NSString *model = [self getDeviceModel];
    if ([model rangeOfString:@"CDMA"].location != NSNotFound ||
        [model isEqualToString:@"Verizon iPhone 4"]) {
        return YES;
    }
    return NO;
}

+ (BOOL) getTelephonyGSMSupported
{
    NSString *model = [self getDeviceModel];
    if ([model rangeOfString:@"GSM"].location != NSNotFound ||
        [model isEqualToString:@"iPhone 1G"] || [model isEqualToString:@"iPhone 3G"] ||
        [model isEqualToString:@"iPhone 3GS"] || [model isEqualToString:@"iPhone 4"]) {
        return YES;
    }
    return NO;
}

+ (BOOL) getTelephonySupported
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]];
}

+ (BOOL) getFingerprintScannerSupported
{
    LAContext *context = [LAContext new];
    return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
}

+ (NSString *) getDeviceName
{
    return [[UIDevice currentDevice] name];
}

+ (NSString *) getDeviceModel
{
    struct utsname systemInfo;

    uname(&systemInfo);

    NSString* code = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];

    NSString* deviceName = [deviceNamesByCode stringForKey:code];

    if (!deviceName) {
        // Just use the code name so we don't lose any information
        deviceName = code;
    }

    return deviceName;
}

+ (CGRect) getScreenSize
{
    return [[UIScreen mainScreen] bounds];
}

+ (NSInteger) getScreenDensity
{
    CGFloat density = [[UIScreen mainScreen] scale];
    return density;
}

+ (NSString *) getTimezone
{
    NSTimeZone *timeZone = [NSTimeZone localTimeZone];
    return [timeZone name];
}

+ (NSString *) getCarrierName
{
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netinfo subscriberCellularProvider];
    NSString *carrierName = [carrier carrierName];

    if (carrierName == nil) {
        return @"unknown";
    }

    return carrierName;
}

+ (NSString *) getVersionString
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *) getLocale
{
    return [[NSLocale currentLocale] localeIdentifier];
}

+ (NSString *) getCountry
{
    return [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
}

+ (NSString *) getCurrency
{
    return [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
}

+ (NSString *) getOsVersion
{
    return [[UIDevice currentDevice] systemVersion];
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
    CLLocation *location = LocationManager.location;
    if (   !location // skip if unavailable
        || [location.timestamp timeIntervalSinceNow] < -300 // skip if older than 5 minutes
        || location.horizontalAccuracy < 0 // skip invalid locations
        || location.horizontalAccuracy > 10000 // skip if less precise then 10 km
    ) {
        return nil;
    }
    return location;
}

@end
