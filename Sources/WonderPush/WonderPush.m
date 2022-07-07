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

#import <UIKit/UIKit.h>
#import <WonderPushCommon/WPNSUtil.h>
#import "WPUtil.h"
#import <WonderPushCommon/WPErrors.h>
#import "WonderPush_private.h"
#import "WPAppDelegate.h"
#import "WPNotificationCenterDelegate.h"
#import "WPConfiguration.h"
#import "WPDialogButtonHandler.h"
#import "WPAPIClient.h"
#import <WonderPushCommon/WPMeasurementsApiClient.h>
#import <WonderPushCommon/WPJsonUtil.h>
#import <WonderPushCommon/WPLog.h>
#import "WPJsonSyncInstallation.h"
#import "WonderPushConcreteAPI.h"
#import "WonderPushLogErrorAPI.h"
#import "WPHTMLInAppController.h"
#import "WPURLFollower.h"
#import "WPAction_private.h"
#import "WPNotificationCategoryHelper.h"
#import "WPIAMRuntimeManager.h"
#import "WPPresenceManager.h"
#import "WPRequestVault.h"
#import "WPIAMMessageDefinition.h"
#import "WPConfiguration.h"
#import "WPIAMWebView.h"

static UIApplicationState _previousApplicationState = UIApplicationStateInactive;
NSString * const WPSubscriptionStatusChangedNotification = @"WPSubscriptionStatusChangedNotification";
NSString * const WPSubscriptionStatusChangedNotificationPreviousStatusInfoKey = @"previousSubscriptionStatus";
NSString * const WPSubscriptionStatusOptIn = @"optIn";
NSString * const WPSubscriptionStatusOptOut = @"optOut";
NSString * const WPTargetUrlModeExternal = @"external";
static BOOL _isInitialized = NO;
static BOOL _isReachable = NO;

static BOOL _beforeInitializationUserIdSet = NO;
static NSString *_beforeInitializationUserId = nil;

static BOOL _userNotificationCenterDelegateInstalled = NO;

__weak static id<WonderPushDelegate> _delegate = nil;
static WPPresenceManager *presenceManager = nil;
@class WPPresenceManagerEventSender;
static WPPresenceManagerEventSender *presenceManagerDelegate = nil;
static WPReportingData *lastClickedNotificationReportingData = nil;

@interface WPPresenceManagerEventSender : NSObject<WPPresenceManagerAutoRenewDelegate>
@end
@implementation WPPresenceManagerEventSender

- (void)presenceManager:(WPPresenceManager *)presenceManager wantsToRenewPresence:(WPPresencePayload *)presence {
    if (!presence) return;
    [WonderPush trackInternalEvent:@"@PRESENCE" eventData:@{@"presence" : presence.toJSON} customData:nil];
}

@end
@implementation WonderPush

static NSString *_integrator = nil;
static NSString *_currentLanguageCode = nil;
static NSArray *validLanguageCodes = nil;
static BOOL _requiresUserConsent = NO;
static id<WonderPushAPI> wonderPushAPI = nil;
static NSMutableDictionary *safeDeferWithConsentIdToBlock = nil;
static NSMutableOrderedSet *safeDeferWithConsentIdentifiers = nil;
static NSMutableArray *safeDeferWithSubscriptionBlocks = nil;
static BOOL _locationOverridden = NO;
static CLLocation *_locationOverride = nil;
static UIStoryboard *storyboard = nil;

NSString * const WPEventFiredNotification = @"WPEventFiredNotification";
NSString * const WPEventFiredNotificationEventTypeKey = @"WPEventFiredNotificationEventTypeKey";
NSString * const WPEventFiredNotificationEventDataKey = @"WPEventFiredNotificationEventDataKey";

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [WPIAMWebView ensureInitialized];
        safeDeferWithSubscriptionBlocks = [NSMutableArray new];
        NSBundle *resourceBundle = [self resourceBundle];
        if (!resourceBundle) {
            WPLog(@"Couldn't find WonderPush.bundle. Please follow the installation instructions at https://docs.wonderpush.com/docs/ios-quickstart.");
        } else {
            @try {
                storyboard = [UIStoryboard storyboardWithName:@"WonderPush" bundle:resourceBundle];
            } @catch (NSException *exception) {
                WPLog(@"Couldn't find WonderPush storyboard. Please make sure you are using a WonderPush.bundle with the same version as WonderPush.framework");
            }
        }
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
            }
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:WPSubscriptionStatusChangedNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
            @synchronized (safeDeferWithSubscriptionBlocks) {
                if (![notification.object isEqualToString:WPSubscriptionStatusOptIn]) {
                    return;
                }
                for (void(^block)(void) in safeDeferWithSubscriptionBlocks) {
                    dispatch_async(dispatch_get_main_queue(), block);
                }
                [safeDeferWithSubscriptionBlocks removeAllObjects];
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

        // Register application lifecycle callbacks
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:UIApplication.sharedApplication queue:nil usingBlock:^(NSNotification *notification) {
            [WonderPush applicationDidEnterBackground_private:notification.object];
        }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:UIApplication.sharedApplication queue:nil usingBlock:^(NSNotification *notification) {
            [WonderPush applicationDidBecomeActive_private:notification.object];
        }];
        [center addObserverForName:UIApplicationWillResignActiveNotification object:UIApplication.sharedApplication queue:nil usingBlock:^(NSNotification *notification) {
            [WonderPush applicationWillResignActive_private:notification.object];
        }];
        
        // Manage blocks by configuration: we're blocking JsonSyn and WPAPIClient right away, we'll unblock them when we have a configuration.
        WPJsonSyncInstallation.disabled = YES;
        WPAPIClient.sharedClient.disabled = YES;

        [[NSNotificationCenter defaultCenter] addObserverForName:WPRemoteConfigUpdatedNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
            [self readConfigAndUpdateDisabledComponents];
        }];
        
        // Listen to measurements API client responses and look for _configVersion
        [center addObserverForName:WPBasicApiClientResponseNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
            id response = notification.object; // WPResponse
            id result = [response object];
            if ([result isKindOfClass:NSDictionary.class]) {
                id configVersion = result[@"_configVersion"];
                if ([configVersion isKindOfClass:NSString.class]) {
                    [WonderPush.remoteConfigManager declareVersion:configVersion];
                } else if ([configVersion isKindOfClass:NSNumber.class]) {
                    [WonderPush.remoteConfigManager declareVersion:[configVersion stringValue]];
                }
            }

        }];
    });
}
+ (WPPresenceManager *)presenceManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        presenceManagerDelegate = [WPPresenceManagerEventSender new];
        presenceManager = [[WPPresenceManager alloc]
                           initWithAutoRenewDelegate:presenceManagerDelegate
                           anticipatedTime:PRESENCE_ANTICIPATED_TIME
                           safetyMarginTime:PRESENCE_UPDATE_SAFETY_MARGIN];
    });
    return presenceManager;
}
+ (NSBundle *) resourceBundle
{
    NSBundle *containerBundle = [NSBundle bundleForClass:[WonderPush class]];
    // CocoaPods copies resources in a bundle named WonderPush.bundle
    // If that bundle exists, that's where we'll find our resources
    NSString *cocoaPodsBundlePath = [[containerBundle resourcePath] stringByAppendingPathComponent:@"WonderPush.bundle"];
    BOOL isDirectory;
    if ([[NSFileManager defaultManager] fileExistsAtPath:cocoaPodsBundlePath isDirectory:&isDirectory] && isDirectory) {
        return [NSBundle bundleWithPath:cocoaPodsBundlePath];
    }
    isDirectory = NO;
    NSString *spmBundlePath = [[containerBundle resourcePath] stringByAppendingPathComponent:@"WonderPush_WonderPush.bundle"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:spmBundlePath isDirectory:&isDirectory] && isDirectory) {
        return [NSBundle bundleWithPath:spmBundlePath];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[containerBundle bundlePath] stringByAppendingPathComponent:@"WonderPush.storyboardc"] isDirectory:&isDirectory] && isDirectory) return containerBundle;
    return nil;
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
    if (hadUserConsent && !userConsent) {
        [WPJsonSyncInstallation flush];
    }
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

+ (void) safeDeferWithSubscription:(void (^)(void))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self subscriptionStatusIsOptIn]) {
            block();
        } else {
            @synchronized(safeDeferWithSubscriptionBlocks) {
                [safeDeferWithSubscriptionBlocks addObject:block];
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
        // Note the server will remove the push token from the current installation once we set it to the new installation
        [[WPJsonSyncInstallation forCurrentUser] receiveDiff:@{@"pushToken":@{@"data": [NSNull null]}}];

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
    
    if (![self hasUserConsent]) {
        [[NSNotificationCenter defaultCenter] addObserverForName:WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED object:self queue:nil usingBlock:^(NSNotification *notification) {
            BOOL hasUserConsent = [notification.userInfo[WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED_KEY] boolValue];
            if (hasUserConsent) {
                // Ensure we have an @APP_OPEN
                [self onInteractionLeaving:NO];
            }
        }];
    }
    
    // Block measurements API client right away
    [self measurementsApiClient].disabled = YES;

    [self readConfigAndUpdateDisabledComponents];
}

+ (void) readConfigAndUpdateDisabledComponents {
    [self.remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {
        if (!config) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self readConfigAndUpdateDisabledComponents];
            });
            return;
        }
        // API client
        WPAPIClient.sharedClient.disabled = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_DISABLE_API_CLIENT_KEY inDictionary:config.data] boolValue];
        // JSONSync
        WPJsonSyncInstallation.disabled = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_DISABLE_JSON_SYNC_KEY inDictionary:config.data] boolValue];
        if (!WPJsonSyncInstallation.disabled) {
            [WPJsonSyncInstallation flush];
        }
        // Measurements API
        [self measurementsApiClient].disabled = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_DISABLE_MEASUREMENTS_API_CLIENT_KEY inDictionary:config.data] boolValue];
        // Events collapsing
        WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_TRACKED_EVENTS_UNCOLLAPSED_MAXIMUM_AGE_MS_KEY inDictionary:config.data defaultValue:[NSNumber numberWithInteger:DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_AGE_MS]] integerValue];
        WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsCount = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_TRACKED_EVENTS_UNCOLLAPSED_MAXIMUM_COUNT_KEY inDictionary:config.data defaultValue:[NSNumber numberWithInteger:DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_COUNT]] integerValue];
        WPConfiguration.sharedConfiguration.maximumCollapsedLastBuiltinTrackedEventsCount = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_TRACKED_EVENTS_COLLAPSED_LAST_BUILTIN_MAXIMUM_COUNT_KEY inDictionary:config.data defaultValue:[NSNumber numberWithInteger:DEFAULT_MAXIMUM_COLLAPSED_LAST_BUILTIN_TRACKED_EVENTS_COUNT]] integerValue];
        WPConfiguration.sharedConfiguration.maximumCollapsedLastCustomTrackedEventsCount = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_TRACKED_EVENTS_COLLAPSED_LAST_CUSTOM_MAXIMUM_COUNT_KEY inDictionary:config.data defaultValue:[NSNumber numberWithInteger:DEFAULT_MAXIMUM_COLLAPSED_LAST_CUSTOM_TRACKED_EVENTS_COUNT]] integerValue];
        WPConfiguration.sharedConfiguration.maximumCollapsedOtherTrackedEventsCount = [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_TRACKED_EVENTS_COLLAPSED_OTHER_MAXIMUM_COUNT_KEY inDictionary:config.data defaultValue:[NSNumber numberWithInteger:DEFAULT_MAXIMUM_COLLAPSED_OTHER_TRACKED_EVENTS_COUNT]] integerValue];
    }];
}

+ (void) initForNewUser:(NSString *)userId
{
//    WPLogDebug(@"initForNewUser:%@", userId);
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    [configuration changeUserId:userId];
    [WPJsonSyncInstallation forCurrentUser]; // ensures static initialization is done
    [self safeDeferWithConsent: ^{
        [WonderPush refreshPreferencesAndConfiguration];
    }];
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

+ (void) refreshPreferencesAndConfiguration
{
    // Refresh core properties
    [self updateInstallationCoreProperties];

    // Refresh push token
    [self setDeviceToken:[WPConfiguration sharedConfiguration].deviceToken];
    [self refreshDeviceTokenIfPossible];

    // Refresh preferences
    [self sendPreferences];
}

+ (void) sendPreferences
{
    [wonderPushAPI sendPreferences];
}

+ (BOOL) isNotificationForWonderPush:(NSDictionary *)userInfo
{
    if ([userInfo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *wonderpushData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:userInfo];
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
    return [WP_PUSH_NOTIFICATION_DATA isEqualToString:[WPNSUtil stringForKey:WP_PUSH_NOTIFICATION_TYPE_KEY inDictionary:([WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:userInfo] ?: @{})]];
}

+ (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback {
    [wonderPushAPI trackInternalEvent:type eventData:data customData:customData sentCallback:sentCallback];
}

+ (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    [wonderPushAPI trackInternalEvent:type eventData:data customData:customData];
}

+ (void) countInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    [wonderPushAPI countInternalEvent:type eventData:data customData:customData];
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

    [WonderPush safeDeferWithConsent:^{
        [wonderPushAPI refreshDeviceTokenIfPossible];
    }];

    if (![WPUtil hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler] // didReceiveRemoteNotification will be called in such a case
        && launchOptions != nil
    ) {
        NSDictionary *notificationDictionary = [WPNSUtil dictionaryForKey:UIApplicationLaunchOptionsRemoteNotificationKey inDictionary:launchOptions];
        if ([notificationDictionary isKindOfClass:[NSDictionary class]]) {
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
        WPLogDebug(@"Will call didReceiveRemoveNotification's fetchCompletionHandler");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WPLogDebug(@"Calling didReceiveRemoveNotification's fetchCompletionHandler");
            completionHandler(UIBackgroundFetchResultNewData);
        });
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
    NSString *newToken = [WPNSUtil hexForData:deviceToken];
    [WonderPush setDeviceToken:newToken];
}

+ (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;

    WPLogDebug(@"Failed to register to push notifications: %@", error);
    if (error.code == 3000) {
        if ([[WPNSUtil stringForKey:NSLocalizedDescriptionKey inDictionary:error.userInfo] rangeOfString:@"aps-environment"].location != NSNotFound) {
            WPLog(@"ERROR: You need to enable the Push Notifications capability under Project / Targets / Signing & Capabilities in XCode.");
        }
    } else if (error.code == 3010) {
        WPLog(@"The iOS Simulator does not support push notifications. You need to use a real iOS device.");
    }

    [WonderPush setDeviceToken:nil];
}

+ (void) applicationDidBecomeActive:(UIApplication *)application {
    // This method is here for background compat only
    // We are now calling [WonderPush applicationDidBecomeActive_private:application] from
    // an NSNotificationCenter notification
}

+ (void) applicationDidBecomeActive_private:(UIApplication *)application
{
//    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
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

    [self refreshPreferencesAndConfiguration];
    [self onInteractionLeaving:NO];
}

+ (void) applicationWillResignActive_private:(UIApplication *)application {
    if (![self isInitialized]) return;
    [WPJsonSyncInstallation flush];
    [self onInteractionLeaving:YES];
}

+ (void) applicationDidEnterBackground:(UIApplication *)application {
    // This method is here for background compat only
    // We are now calling [WonderPush applicationDidEnterBackground_private:application] from
    // an NSNotificationCenter notification
}

+ (void) applicationDidEnterBackground_private:(UIApplication *)application
{
    WPLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (![self isInitialized]) return;
    if ([WPAppDelegate isAlreadyRunning]) return;
    _previousApplicationState = UIApplicationStateBackground;

    WPPresencePayload *presence = [WonderPush presenceManager].isCurrentlyPresent ? [[WonderPush presenceManager] presenceWillStop] : nil;
    if (presence) {
        [WonderPush trackInternalEvent:@"@PRESENCE" eventData:@{@"presence" : presence.toJSON} customData:nil];
    }

    // Send queued notifications as LocalNotifications
    if ([self hasUserConsent]) {
        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        if (![WPUtil currentApplicationIsInForeground]) {
            NSArray *queuedNotifications = [configuration getQueuedNotifications];
            for (NSDictionary *userInfo in queuedNotifications) {
                if (![userInfo isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *aps = [WPNSUtil dictionaryForKey:@"aps" inDictionary:userInfo];
                NSDictionary *alertDict = [WPNSUtil dictionaryForKey:@"alert" inDictionary:aps];
                NSString *title = alertDict ? [WPNSUtil stringForKey:@"title" inDictionary:alertDict] : nil;
                NSString *alert = alertDict ? [WPNSUtil stringForKey:@"body" inDictionary:alertDict] : [WPNSUtil stringForKey:@"alert" inDictionary:aps];
                NSString *sound = [WPNSUtil stringForKey:@"sound" inDictionary:aps];
                if (@available(iOS 10.0, *)) {
                    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                    if (title) content.title = title;
                    if (alert) content.body = alert;
                    if (sound) content.sound = [UNNotificationSound soundNamed:sound];
                    content.userInfo = userInfo;
                    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString] content:content trigger:nil];
                    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
                } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    UILocalNotification *notification = [[UILocalNotification alloc] init];
                    notification.alertBody = alert;
                    notification.soundName = [WPNSUtil stringForKey:@"sound" inDictionary:aps];
                    notification.userInfo = [WPNSUtil dictionaryByFilteringNulls:userInfo];
                    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
#pragma clang diagnostic pop
                }
            }
        }
        [configuration clearQueuedNotifications];
    }

}

+ (void) application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [self safeDeferWithConsent:^{
        [WonderPush refreshPreferencesAndConfiguration];
    }];
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
        completionHandler(presentationOptions);
        return;
    }

    // Ensure that we display the notification even if the application is in foreground
    NSDictionary *wpData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:userInfo];
    NSDictionary *apsForeground = [WPNSUtil dictionaryForKey:@"apsForeground" inDictionary:wpData];
    if (!apsForeground || apsForeground.count == 0) apsForeground = nil;
    BOOL apsForegroundAutoOpen = NO;
    BOOL apsForegroundAutoDrop = NO;
    if (apsForeground) {
        apsForegroundAutoOpen = [[WPNSUtil numberForKey:@"autoOpen" inDictionary:apsForeground] isEqual:@YES];
        apsForegroundAutoDrop = [[WPNSUtil numberForKey:@"autoDrop" inDictionary:apsForeground] isEqual:@YES];
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
    [self handleNotificationOpened:response.notification.request.content.userInfo withResponse:response];
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

+ (void) setIntegrator:(NSString *)integrator
{
    _integrator = integrator;
}

+ (NSString *)getIntegrator
{
    return _integrator;
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

+ (void)receivedFullInstallationFromServer:(NSDictionary *)installation updateDate:(NSDate *)installationUpdateDate
{
    WPLogDebug(@"Synchronizing installation");
    [[WPJsonSyncInstallation forCurrentUser] receiveState:installation resetSdkState:false];
}

+ (void) trackNotificationOpened:(NSDictionary *)eventData
{
    WPReportingData *reportingData = [WPReportingData extract:eventData];
    lastClickedNotificationReportingData = reportingData;
    [self trackInternalEvent:@"@NOTIFICATION_OPENED" eventData:eventData customData:nil];
}

+ (void) trackNotificationReceived:(NSDictionary *)userInfo
{
    if (![WonderPush isNotificationForWonderPush:userInfo]) return;
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    NSDictionary *wpData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:userInfo];
    WPReportingData *reportingData = [WPReportingData extract:wpData];
    id receipt        = conf.overrideNotificationReceipt ?: [WPNSUtil nullsafeObjectForKey:@"receipt" inDictionary:wpData];
    id receiptUsingMeasurements = [WPNSUtil nullsafeObjectForKey:@"receiptUsingMeasurements" inDictionary:wpData];
    conf.lastReceivedNotificationDate = [NSDate date];
    conf.lastReceivedNotification = [reportingData eventDataValue];
    if ([receipt boolValue] && ![receiptUsingMeasurements boolValue]) {
        [self trackInternalEvent:@"@NOTIFICATION_RECEIVED" eventData:[reportingData eventDataValue] customData:nil];
    }

    // Track lastReceivedNotificationCheckDate
    NSTimeInterval lastReceivedNotificationCheckDelay = [([WPNSUtil numberForKey:@"lastReceivedNotificationCheckDelay" inDictionary:wpData] ?: [NSNumber numberWithDouble:DEFAULT_LAST_RECEIVED_NOTIFICATION_CHECK_DELAY * 1000]) doubleValue] / 1000;
    WPJsonSyncInstallation *installation = [WPJsonSyncInstallation forCurrentUser];
    NSNumber *lastReceivedNotificationCheckDateMs = installation.sdkState[LAST_RECEIVED_NOTIFICATION_CHECK_DATE_PROPERTY];
    NSDate *lastReceivedNotificationCheckDate = [NSDate dateWithTimeIntervalSince1970:lastReceivedNotificationCheckDateMs.doubleValue / 1000];
    NSDate *now = [NSDate date];
    BOOL reportLastReceivedNotificationCheckDate = !lastReceivedNotificationCheckDate || ([now timeIntervalSinceDate:lastReceivedNotificationCheckDate] > lastReceivedNotificationCheckDelay);
    if (reportLastReceivedNotificationCheckDate) {
        [installation put:@{ LAST_RECEIVED_NOTIFICATION_CHECK_DATE_PROPERTY : [NSNumber numberWithLong:(long)(now.timeIntervalSince1970 * 1000)]  }];
    }
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[WPNSUtil stringForKey:@"title" inDictionary:wonderPushData] message:[WPNSUtil stringForKey:@"message" inDictionary:wonderPushData] preferredStyle:UIAlertControllerStyleAlert];

    NSArray *buttons = [WPNSUtil arrayForKey:@"buttons" inDictionary:wonderPushData];
    WPDialogButtonHandler *buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.notificationConfiguration = wonderPushData;
    buttonHandler.buttonConfiguration = buttons;
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        int i = -1;
        for (NSDictionary *button in buttons) {
            int index = ++i;
            if (![button isKindOfClass:[NSDictionary class]]) continue;
            [alert addAction:[UIAlertAction actionWithTitle:[WPNSUtil stringForKey:@"label" inDictionary:button] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
    NSArray *buttons = [WPNSUtil arrayForKey:@"buttons" inDictionary:wonderPushData];
    WPDialogButtonHandler *buttonHandler = [[WPDialogButtonHandler alloc] init];
    buttonHandler.buttonConfiguration = buttons;
    buttonHandler.notificationConfiguration = wonderPushData;
    NSMutableArray *alertButtons = [[NSMutableArray alloc] initWithCapacity:MIN(1, [buttons count])];
    if ([buttons isKindOfClass:[NSArray class]] && [buttons count] > 0) {
        int i = -1;
        for (NSDictionary *button in buttons) {
            ++i;
            [alertButtons addObject:[WPHTMLInAppAction actionWithTitle:[WPNSUtil stringForKey:@"label" inDictionary:button] block:^(WPHTMLInAppAction *action) {
                [buttonHandler clickedButtonAtIndex:i];
            }]];
        }
    } else {
        [alertButtons addObject:[WPHTMLInAppAction actionWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL block:^(WPHTMLInAppAction *action) {
            [buttonHandler clickedButtonAtIndex:0];
        }]];
    }

    WPHTMLInAppController *controller = [storyboard instantiateViewControllerWithIdentifier:@"HTMLInAppController"];
    controller.title = [WPNSUtil stringForKey:@"title" inDictionary:wonderPushData];
    controller.actions = [alertButtons copy];
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    controller.HTMLString = [WPNSUtil stringForKey:@"message" inDictionary:wonderPushData];
    NSString *URLString = [WPNSUtil stringForKey:@"url" inDictionary:wonderPushData];
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

+ (void) executeAction:(WPAction *)action withReportingData:(WPReportingData *)reportingData
{
    [wonderPushAPI executeAction:action withReportingData:reportingData];
}

+ (void) setDeviceToken:(NSString *)deviceToken
{
    [wonderPushAPI setDeviceToken:deviceToken];
}

+ (void) hasAcceptedVisibleNotificationsWithCompletionHandler:(void(^)(BOOL result))handler;
{
    if (@available(iOS 10.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            handler(settings.authorizationStatus != UNAuthorizationStatusNotDetermined && settings.authorizationStatus != UNAuthorizationStatusDenied);
        }];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        handler([[UIApplication sharedApplication] currentUserNotificationSettings].types != 0);
#pragma clang diagnostic pop
    }
}

+ (BOOL) handleNotification:(NSDictionary*)notificationDictionary
{
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotification:%@", notificationDictionary);

    [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_RECEIVED object:nil userInfo:notificationDictionary];

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
            NSDictionary *wonderpushData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:notificationDictionary];
            id atReceptionActions = [WPNSUtil arrayForKey:@"receiveActions" inDictionary:wonderpushData];
            if ([atReceptionActions isKindOfClass:NSArray.class]) {
                WPAction *action = [WPAction actionWithDictionaries:atReceptionActions];
                WPReportingData *reportingData = [WPReportingData extract:wonderpushData];
                [self executeAction:action withReportingData:reportingData];
            }

            [WonderPush trackNotificationReceived:notificationDictionary];
        }
    }

    if (appState == UIApplicationStateBackground) {
        [self refreshPreferencesAndConfiguration];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // The application won't run long enough to perform any scheduled updates of custom properties to the server
            // that may have been asked by receiveActions, flush now.
            // If we had no such modifications, this is still an opportunity to flush any interrupted calls.
            [WPJsonSyncInstallation flush];
        });
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

    NSDictionary *wonderpushData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:notificationDictionary];
    NSDictionary *apsForeground = [WPNSUtil dictionaryForKey:@"apsForeground" inDictionary:wonderpushData];
    if (!apsForeground || apsForeground.count == 0) apsForeground = nil;
    BOOL apsForegroundAutoOpen = NO;
    BOOL apsForegroundAutoDrop = NO;
    if (apsForeground) {
        apsForegroundAutoOpen = [[WPNSUtil numberForKey:@"autoOpen" inDictionary:apsForeground] isEqual:@YES];
        apsForegroundAutoDrop = [[WPNSUtil numberForKey:@"autoDrop" inDictionary:apsForeground] isEqual:@YES];
    }

    if (![WPUtil hasBackgroundModeRemoteNotification]) {
        // We have no remote-notification background execution mode but we try our best to honor receiveActions when we can
        // (they will not be honored for silent notifications, nor for regular notifications that are not clicked)
        NSDictionary *wonderpushData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:notificationDictionary];
        id atReceptionActions = [WPNSUtil arrayForKey:@"receiveActions" inDictionary:wonderpushData];
        if ([atReceptionActions isKindOfClass:NSArray.class]) {
            WPAction *action = [WPAction actionWithDictionaries:atReceptionActions];
            WPReportingData *reportingData = [WPReportingData extract:wonderpushData];
            [self executeAction:action withReportingData:reportingData];
        }
    }

    // Should we merely drop this notification if received in foreground?
    if (applicationState == UIApplicationStateActive && apsForegroundAutoDrop) {
        WPLogDebug(@"Dropping notification received in foreground like demanded");
        return NO;
    }

    NSDictionary *aps = [WPNSUtil dictionaryForKey:@"aps" inDictionary:notificationDictionary];
    if (!aps || aps.count == 0) aps = nil;
    NSDictionary *apsAlert = aps ? [WPNSUtil nullsafeObjectForKey:@"alert" inDictionary:aps] : nil;

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
            title = [WPNSUtil stringForKey:@"title-loc-key" inDictionary:apsAlert];
            if (title) title = [WPUtil localizedStringIfPossible:title];
            if (title) {
                id locArgsId = [WPNSUtil arrayForKey:@"title-loc-args" inDictionary:apsAlert];
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
                title = [WPNSUtil stringForKey:@"title" inDictionary:apsAlert];
            }
            alert = [WPNSUtil stringForKey:@"loc-key" inDictionary:apsAlert];
            if (alert) alert = [WPUtil localizedStringIfPossible:alert];
            if (alert) {
                id locArgsId = [WPNSUtil arrayForKey:@"loc-args" inDictionary:apsAlert];
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
                alert = [WPNSUtil stringForKey:@"body" inDictionary:apsAlert];
            }
            action = [WPNSUtil stringForKey:@"action-loc-key" inDictionary:apsAlert];
            if (action) action = [WPUtil localizedStringIfPossible:action];
        } else if ([apsAlert isKindOfClass:[NSString class]]) {
            alert = (NSString *)apsAlert;
        }
        if (!title) title = [WPNSUtil stringForKey:@"CFBundleDisplayName" inDictionary:localizedInfoDictionary];
        if (!title) title = [WPNSUtil stringForKey:@"CFBundleDisplayName" inDictionary:infoDictionary];
        if (!title) title = [WPNSUtil stringForKey:@"CFBundleName" inDictionary:localizedInfoDictionary];
        if (!title) title = [WPNSUtil stringForKey:@"CFBundleName" inDictionary:infoDictionary];
        if (!title) title = [WPNSUtil stringForKey:@"CFBundleExecutable" inDictionary:localizedInfoDictionary];
        if (!title) title = [WPNSUtil stringForKey:@"CFBundleExecutable" inDictionary:infoDictionary];

        if (!action) {
            action = [WPUtil wpLocalizedString:@"VIEW" withDefault:@"View"];
        }
        if (alert) {
            UIAlertController *systemLikeAlert = [UIAlertController alertControllerWithTitle:title message:alert preferredStyle:UIAlertControllerStyleAlert];
            [systemLikeAlert addAction:[UIAlertAction actionWithTitle:[WPUtil wpLocalizedString:@"CLOSE" withDefault:@"Close"] style:UIAlertActionStyleCancel handler:nil]];
            [systemLikeAlert addAction:[UIAlertAction actionWithTitle:action style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [WonderPush handleNotificationOpened:notificationDictionary withResponse:nil];
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
        return [self handleNotificationOpened:notificationDictionary withResponse:nil];

    }

    return NO;
}

+ (BOOL) handleNotificationOpened:(NSDictionary*)notificationDictionary withResponse:(id)response {
    if (![WonderPush isNotificationForWonderPush:notificationDictionary])
        return NO;
    WPLogDebug(@"handleNotificationOpened:%@", notificationDictionary);

    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    conf.justOpenedNotification = notificationDictionary;

    NSDictionary *wonderpushData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:notificationDictionary];
    WPLogDebug(@"Opened notification: %@", notificationDictionary);

    [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_OPENED object:nil userInfo:notificationDictionary];

    WPReportingData *reportingData = [WPReportingData extract:wonderpushData];
    NSMutableDictionary *notificationOpenedEventData = [NSMutableDictionary new];
    [reportingData fillEventDataInto:notificationOpenedEventData];

    NSString *targetUrl = [WPNSUtil stringForKey:WP_TARGET_URL_KEY inDictionary:wonderpushData];
    NSString *targetUrlMode = [WPNSUtil stringForKey:WP_TARGET_URL_MODE_KEY inDictionary:wonderpushData];
    id actionsToExecute = [WPNSUtil arrayForKey:@"actions" inDictionary:wonderpushData];

    if (@available(iOS 10.0, *)) {
        WPNotificationCategoryHelper *categoryHelper = [WPNotificationCategoryHelper sharedInstance];
        UNNotificationResponse *notificationResponse = [response isKindOfClass:UNNotificationResponse.class] ? (UNNotificationResponse *)response : nil;
        if (notificationResponse && notificationResponse.actionIdentifier && [categoryHelper isWonderPushActionIdentifier:notificationResponse.actionIdentifier]) {
            NSInteger indexOfButton = [categoryHelper indexOfButtonWithActionIdentifier:notificationResponse.actionIdentifier];
            NSDictionary *alertDict = [WPNSUtil dictionaryForKey:@"alert" inDictionary:wonderpushData];
            NSArray *buttons = [alertDict isKindOfClass:NSDictionary.class] ? [WPNSUtil arrayForKey:@"buttons" inDictionary:alertDict] : nil;
            if (buttons && indexOfButton >= 0 && indexOfButton < buttons.count) {
                NSDictionary *button = [buttons objectAtIndex:indexOfButton];
                actionsToExecute = [WPNSUtil arrayForKey:@"actions" inDictionary:button];
                targetUrl = [WPNSUtil stringForKey:@"targetUrl" inDictionary:button];
                NSString *buttonLabel = [WPNSUtil stringForKey:@"label" inDictionary:button];
                if (buttonLabel) notificationOpenedEventData[@"buttonLabel"] = buttonLabel;
            }
        }
    }

    [self trackNotificationOpened:[notificationOpenedEventData copy]];

    if ([actionsToExecute isKindOfClass:NSArray.class]) {
        WPAction *action = [WPAction actionWithDictionaries:actionsToExecute];
        [self executeAction:action withReportingData:reportingData];
    }

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
            [self openURL:[NSURL URLWithString:targetUrl] targetUrlMode:targetUrlMode];
        });
    }

    if ([self isDataNotification:notificationDictionary]) {
        WPLogDebug(@"handleNotificationOpened: data notification stopping");
        return NO;
    } else if ([targetUrl isEqualToString:WP_TARGET_URL_NOOP]) {
        return NO;
    }
    NSDictionary *inAppData = [WPNSUtil dictionaryForKey:@"inApp" inDictionary:wonderpushData];
    if (inAppData) {
        WPIAMMessageRenderData *renderData = [WPIAMFetchResponseParser renderDataFromNotificationDict:inAppData isTestMessage:YES];
        if (renderData) {
            WPIAMCappingDefinition *capping = [[WPIAMCappingDefinition alloc] initWithMaxImpressions:1 snoozeTime:0];
            id payload = inAppData[@"payload"] ?: @{};
            WPIAMMessageDefinition *messageDefinition = [[WPIAMMessageDefinition alloc] initWithRenderData:renderData payload:payload startTime:0 endTime:DBL_MAX triggerDefinition:@[] capping:capping segmentDefinition:nil];
            void(^showInApp)(void) = ^() {
                [WPIAMRuntimeManager.getSDKRuntimeInstance.displayExecutor displayMessage:messageDefinition triggerType:WPInAppMessagingDisplayTriggerTypeOnWonderPushEvent delay:0];
            };
            if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                showInApp();
            } else {
                __block id observer;
                observer = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
                    showInApp();
                    [NSNotificationCenter.defaultCenter removeObserver:observer];
                }];
            }
        }
    } else {
        NSString *type = [WPNSUtil stringForKey:@"type" inDictionary:wonderpushData];
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

    if (!leaving) {
        WPPresenceManager *presenceManager = [WonderPush presenceManager];
        WPPresencePayload *presence = presenceManager.isCurrentlyPresent ? nil : [presenceManager presenceDidStart];
        [self sendPresenceAndAppOpenIfNecessary:presence];
    } else {
        [WonderPush.remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {
            if ([config.data[WP_REMOTE_CONFIG_DO_NOT_SEND_PRESENCE_ON_APPLICATION_WILL_RESIGN_ACTIVE] boolValue]) {
                return;
            }
            WPPresencePayload *presence = [WonderPush presenceManager].isCurrentlyPresent ? [[WonderPush presenceManager] presenceWillStop] : nil;
            if (presence) {
                [WonderPush trackInternalEvent:@"@PRESENCE" eventData:@{@"presence" : presence.toJSON} customData:nil];
            }
        }];
    }

    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    conf.lastInteractionDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[NSDate date] timeIntervalSince1970]];
}

+ (void) sendPresenceAndAppOpenIfNecessary:(WPPresencePayload * _Nullable)presence {
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    long long lastInteractionTs = (long long)([conf.lastInteractionDate timeIntervalSince1970] * 1000);
    long long lastReceivedNotificationTs = conf.lastReceivedNotificationDate ? (long long)([conf.lastReceivedNotificationDate timeIntervalSince1970] * 1000) : LONG_LONG_MAX;
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
    static BOOL appOpenQueued = NO;

    // Non-subscribers will have an up-to-date lastInteraction time.
    // Queue an @APP_OPEN event if we've never sent one to the server and haven't already queued one.
    // This will ensure newly subscribed users have at least one @APP_OPEN event in their timeline.
    if (!conf.lastAppOpenSentDate && !appOpenQueued) {
        shouldInjectAppOpen = YES;
    }

    if (shouldInjectAppOpen) {

        // We will track a new app open event
        // Clear the lastClickedNotificationReportingData
        lastClickedNotificationReportingData = nil;

        // Track the new app open event
        NSMutableDictionary *openInfo = [NSMutableDictionary new];

        // Add the elapsed time between the last received notification
        if ([WPUtil hasBackgroundModeRemoteNotification] && lastReceivedNotificationTs <= now) {
            openInfo[@"lastReceivedNotificationTime"] = [[NSNumber alloc] initWithLongLong:now - lastReceivedNotificationTs];
        }
        // Add the information of the clicked notification
        if (conf.justOpenedNotification) {
            lastClickedNotificationReportingData = [WPReportingData extract:[WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:conf.justOpenedNotification]];
            [lastClickedNotificationReportingData fillEventDataInto:openInfo];
            conf.justOpenedNotification = nil;
        }
        if (presence) openInfo[@"presence"] = presence.toJSON;
        
        // When user is not optIn, the SDK API client is disabled.
        // This @APP_OPEN will be sent at a later date or never, so we send an @VISIT right away and we tell the server not to synthesize @VISIT from this @APP_OPEN.
        // If user is optIn, we do NOT send @VISIT at all and rely on the server's behavior of synthesizing this event from @APP_OPEN events.

        if (![self subscriptionStatusIsOptIn]) {
            [WonderPush countInternalEvent:@"@VISIT" eventData:[NSDictionary dictionaryWithDictionary:openInfo] customData:nil];
            openInfo[@"doNotSynthesizeVisit"] = @YES;
        }

        NSDictionary *openInfoCopy = [openInfo copy];
        conf.lastAppOpenDate = [[NSDate alloc] initWithTimeIntervalSince1970:now / 1000.];
        conf.lastAppOpenInfo = openInfoCopy;
        [WonderPush trackInternalEvent:@"@APP_OPEN" eventData:openInfoCopy customData:nil sentCallback:^{
            conf.lastAppOpenSentDate = [NSDate date];
        }];
        appOpenQueued = YES;
    } else if (presence) {
        [WonderPush trackInternalEvent:@"@PRESENCE" eventData:@{@"presence" : presence.toJSON} customData:nil];
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
    request.params = [parameters copy];

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
    request.params = [parameters copy];

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
    request.params = [parameters copy];
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
    request.params = [parameters copy];
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
    request.params = [parameters copy];
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
    request.params = [parameters copy];
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
    if (_locationOverridden) {
        return _locationOverride;
    }
    return [wonderPushAPI location];
}

+ (void) triggerLocationPrompt
{
    [wonderPushAPI triggerLocationPrompt];
}
+ (void) enableGeolocation
{
    _locationOverridden = NO;
    _locationOverride = nil;
}

+ (void) disableGeolocation
{
    [self setGeolocation:nil];
}

+ (void) setGeolocation:(CLLocation *)location
{
    _locationOverridden = YES;
    _locationOverride = location;
}

+ (NSString *) country
{
    NSString * rtn = [WPConfiguration sharedConfiguration].country;
    if (rtn == nil) {
        rtn = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    }
    return rtn;
}

+ (void) setCountry:(NSString *)country
{
    if (country != nil) {
        // Validate against simple expected values,
        // but accept any input as is
        NSString *countryUC = [country uppercaseString];
        if ([country length] != 2) {
            WPLog(@"The given country %@ is not of the form XX of ISO 3166-1 alpha-2", country);
        } else if (!(
                     [countryUC characterAtIndex:0] >= 'A' && [countryUC characterAtIndex:0] <= 'Z'
                     && [countryUC characterAtIndex:1] >= 'A' && [countryUC characterAtIndex:1] <= 'Z'
                   )) {
            WPLog(@"The given country %@ is not of the form XX of ISO 3166-1 alpha-2", country);
        } else {
            // Normalize simple expected value into XX
            country = countryUC;
        }
    }
    [WPConfiguration sharedConfiguration].country = country;
    [self refreshPreferencesAndConfiguration];
}

+ (NSString *) currency
{
    NSString * rtn = [WPConfiguration sharedConfiguration].currency;
    if (rtn == nil) {
        rtn = [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
    }
    return rtn;
}

+ (void) setCurrency:(NSString *)currency
{
    if (currency != nil) {
        // Validate against simple expected values,
        // but accept any input as is
        NSString *currencyUC = [currency uppercaseString];
        if ([currency length] != 3) {
            WPLog(@"The given currency %@ is not of the form XXX of ISO 4217", currency);
        } else if (!(
                     [currencyUC characterAtIndex:0] >= 'A' && [currencyUC characterAtIndex:0] <= 'Z'
                     && [currencyUC characterAtIndex:1] >= 'A' && [currencyUC characterAtIndex:1] <= 'Z'
                     && [currencyUC characterAtIndex:2] >= 'A' && [currencyUC characterAtIndex:2] <= 'Z'
                   )) {
            WPLog(@"The given currency %@ is not of the form XXX of ISO 4217", currency);
        } else {
            // Normalize simple expected value into XXX
            currency = currencyUC;
        }
    }
    [WPConfiguration sharedConfiguration].currency = currency;
    [self refreshPreferencesAndConfiguration];
}

+ (NSString *) locale
{
    NSString * rtn = [WPConfiguration sharedConfiguration].locale;
    if (rtn == nil) {
        rtn = [[NSLocale currentLocale] localeIdentifier];
    }
    return rtn;
}

+ (void) setLocale:(NSString *)locale
{
    if (locale != nil) {
        // Validate against simple expected values,
        // but accept any input as is
        NSString *localeUC = [locale uppercaseString];
        if ([locale length] != 2 && [locale length] != 5) {
            WPLog(@"The given locale %@ is not of the form xx-XX of RFC 1766", locale);
        } else if (!(
                     [localeUC characterAtIndex:0] >= 'A' && [localeUC characterAtIndex:0] <= 'Z'
                     && [localeUC characterAtIndex:1] >= 'A' && [localeUC characterAtIndex:1] <= 'Z'
                     && (
                         [locale length] == 2
                         || (
                             [locale length] == 5
                             && ([localeUC characterAtIndex:2] == '-' || [localeUC characterAtIndex:2] == '_')
                             && [localeUC characterAtIndex:3] >= 'A' && [localeUC characterAtIndex:3] <= 'Z'
                             && [localeUC characterAtIndex:4] >= 'A' && [localeUC characterAtIndex:4] <= 'Z'
                         )
                     )
                   )) {
            WPLog(@"The given locale %@ is not of the form xx-XX of RFC 1766", locale);
        } else {
            // Normalize simple expected value into xx_XX
            if ([locale length] == 5) {
                locale = [NSString stringWithFormat:@"%@_%@", [[locale substringToIndex:2] lowercaseString], [[locale substringWithRange:NSMakeRange(3, 2)] uppercaseString]];
            } else {
                locale = [[locale substringToIndex:2] lowercaseString];
            }
        }
    }
    [WPConfiguration sharedConfiguration].locale = locale;
    [self refreshPreferencesAndConfiguration];
}

+ (NSString *) timeZone
{
    NSString * rtn = [WPConfiguration sharedConfiguration].timeZone;
    if (rtn == nil) {
        rtn = [[NSTimeZone localTimeZone] name];
    }
    return rtn;
}

+ (void) setTimeZone:(NSString *)timeZone
{
    if (timeZone != nil) {
        // Validate against simple expected values,
        // but accept any input as is
        NSString *timeZoneUC = [timeZone uppercaseString];
        if ([timeZone containsString:@"/"]) {
            if (!(
                  [timeZone hasPrefix:@"Africa/"]
                  || [timeZone hasPrefix:@"America/"]
                  || [timeZone hasPrefix:@"Antarctica/"]
                  || [timeZone hasPrefix:@"Asia/"]
                  || [timeZone hasPrefix:@"Atlantic/"]
                  || [timeZone hasPrefix:@"Australia/"]
                  || [timeZone hasPrefix:@"Etc/"]
                  || [timeZone hasPrefix:@"Europe/"]
                  || [timeZone hasPrefix:@"Indian/"]
                  || [timeZone hasPrefix:@"Pacific/"]
                  ) || [timeZone hasSuffix:@"/"]) {
                WPLog(@"The given time zone \"%@\" is not of the form Continent/Country or ABBR of IANA time zone database codes", timeZone);
            }
        } else {
            BOOL allLetters = YES;
            for (int i = 0; i < [timeZoneUC length]; ++i) {
                if ([timeZoneUC characterAtIndex:i] < 'A' || [timeZoneUC characterAtIndex:i] > 'Z') {
                    allLetters = NO;
                    break;
                }
            }
            if (!allLetters) {
                WPLog(@"The given time zone \"%@\" is not of the form Continent/Country or ABBR of IANA time zone database codes", timeZone);
            } else if (!([timeZone length] == 1
                         || [timeZoneUC hasSuffix:@"T"]
                         || [timeZoneUC isEqualToString:@"UTC"]
                         || [timeZoneUC isEqualToString:@"AOE"]
                         || [timeZoneUC isEqualToString:@"MSD"]
                         || [timeZoneUC isEqualToString:@"MSK"]
                         || [timeZoneUC isEqualToString:@"WIB"]
                         || [timeZoneUC isEqualToString:@"WITA"])) {
                WPLog(@"The given time zone \"%@\" is not of the form Continent/Country or ABBR of IANA time zone database codes", timeZone);
            } else {
                // Normalize abbreviations in uppercase
                timeZone = timeZoneUC;
            }
        }
    }
    [WPConfiguration sharedConfiguration].timeZone = timeZone;
    [self refreshPreferencesAndConfiguration];
}

#pragma mark - Open URL
+ (void) openURL:(NSURL *)url targetUrlMode:(NSString *)targetUrlMode
{
    __block bool completionHandlerCalled = NO;
    void (^completionHandler)(NSURL *url) = ^(NSURL *url){
        WPLogDebug(@"openURL completion handler called with: %@", url);
        if (completionHandlerCalled) {
            return;
        } else {
            completionHandlerCalled = YES;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url == nil) return;
            if ([targetUrlMode isEqualToString:WPTargetUrlModeExternal]) {
                [[WPURLFollower URLFollower] followURLViaIOS:url withCompletionBlock:^(BOOL success) {
                    WPLogDebug(@"Successfully opened %@", url);
                }];
                return;
            }
            [[WPURLFollower URLFollower]
             followURL:url
             withCompletionBlock:^(BOOL success) {
                WPLogDebug(@"Successfully opened %@", url);
            }];
        });
    };

    if (!_delegate) {
        WPLogDebug(@"No delegate, calling completion handler in main thread");
        completionHandler(url);
    } else {
        if ([_delegate respondsToSelector:@selector(wonderPushWillOpenURL:withCompletionHandler:)]) {
            WPLogDebug(@"Has async delegate, will call it in main thread");
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!completionHandlerCalled) {
                        WPLog(@"Delegate did not call wonderPushWillOpenURL:withCompletionHandler:'s completion handler fast enough. Continuing normal processing.");
                        completionHandler(url);
                    }
                });
                [_delegate wonderPushWillOpenURL:url withCompletionHandler:completionHandler];
            });
        } else if ([_delegate respondsToSelector:@selector(wonderPushWillOpenURL:)]) {
            WPLogDebug(@"Has sync delegate, will call it in main thread");
            dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                NSURL *newUrl = [_delegate wonderPushWillOpenURL:url];
#pragma clang diagnostic pop
                completionHandler(newUrl);
            });
        }
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

+ (void) setProperty:(NSString *)field value:(id)value
{
    [wonderPushAPI setProperty:field value:value];
}

+ (void) unsetProperty:(NSString *)field;
{
    [wonderPushAPI unsetProperty:field];
}

+ (void) addProperty:(NSString *)field value:(id)value;
{
    [wonderPushAPI addProperty:field value:value];
}

+ (void) removeProperty:(NSString *)field value:(id)value;
{
    [wonderPushAPI removeProperty:field value:value];
}

+ (id) getPropertyValue:(NSString *)field;
{
    return [wonderPushAPI getPropertyValue:field];
}

+ (NSArray *) getPropertyValues:(NSString *)field;
{
    return [wonderPushAPI getPropertyValues:field];
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

+ (void) addTag:(NSString *)tag
{
    [wonderPushAPI addTag:tag];
}

+ (void) addTags:(NSArray<NSString *> *)tags
{
    [wonderPushAPI addTags:tags];
}

+ (void) removeTag:(NSString *)tag
{
    [wonderPushAPI removeTag:tag];
}

+ (void) removeTags:(NSArray<NSString *> *)tags
{
    [wonderPushAPI removeTags:tags];
}

+ (void) removeAllTags
{
    [wonderPushAPI removeAllTags];
}

+ (NSOrderedSet<NSString *> *) getTags
{
    return [wonderPushAPI getTags];
}

+ (bool) hasTag:(NSString *)tag
{
    return [wonderPushAPI hasTag:tag];
}

#pragma mark - RemoteConfig

+ (WPRemoteConfigManager *) remoteConfigManager {
    static NSMutableDictionary *managers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        managers = [NSMutableDictionary new];
    });
    
    NSString *clientId = WPConfiguration.sharedConfiguration.clientId;
    if (!clientId) return nil;
    
    @synchronized (self) {
        WPRemoteConfigManager *remoteConfigManager = managers[clientId];
        if (!remoteConfigManager) {
            WPRemoteConfigFetcherWithURLSession *fetcher = [[WPRemoteConfigFetcherWithURLSession alloc] initWithClientId:clientId];
            WPRemoteConfigStorageWithUserDefaults *storage = [[WPRemoteConfigStorageWithUserDefaults alloc] initWithClientId:clientId];
            remoteConfigManager = [[WPRemoteConfigManager alloc] initWithRemoteConfigFetcher:fetcher storage:storage];
            managers[clientId] = remoteConfigManager;
        }
        return remoteConfigManager;
    }
}

+ (void)requestEventuallyWithMeasurementsApi:(WPRequest *)request {
    WPRequestVault *vault = [self measurementsApiRequestVault];
    [vault add:request];
}

+ (WPRequestVault *)measurementsApiRequestVault {
    static NSMutableDictionary *vaults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vaults = [NSMutableDictionary new];
    });
    
    NSString *clientId = WPConfiguration.sharedConfiguration.clientId;
    NSString *clientSecret = WPConfiguration.sharedConfiguration.clientSecret;
    if (!clientId || !clientSecret) return nil;
    
    WPRequestVault *vault = vaults[clientId];
    if (!vault) {
        vault = [[WPRequestVault alloc] initWithRequestExecutor:[self measurementsApiClient]];
        vaults[clientId] = vault;
    }
    return vault;
}
+ (WPMeasurementsApiClient *)measurementsApiClient {
    static NSMutableDictionary *clients;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        clients = [NSMutableDictionary new];
    });
    
    NSString *clientId = WPConfiguration.sharedConfiguration.clientId;
    NSString *clientSecret = WPConfiguration.sharedConfiguration.clientSecret;
    if (!clientId || !clientSecret) return nil;
    
    WPMeasurementsApiClient *client = clients[clientId];
    if (!client) {
        client = [[WPMeasurementsApiClient alloc]
                  initWithClientId:clientId secret:clientSecret deviceId:[WPUtil deviceIdentifier]];
        clients[clientId] = client;
    }
    return client;
}

+ (WPReportingData * _Nullable)lastClickedNotificationReportingData {
    return lastClickedNotificationReportingData;
}

+ (NSString *)subscriptionStatus {
    WPJsonSyncInstallation *installation = [WPJsonSyncInstallation forCurrentUser];
    NSString *subscriptionStatus = installation.sdkState[@"preferences"][@"subscriptionStatus"];
    if (!subscriptionStatus) return nil;
    if ([WPSubscriptionStatusOptIn isEqualToString:subscriptionStatus]) {
        return WPSubscriptionStatusOptIn;
    }
    if ([WPSubscriptionStatusOptOut isEqualToString:subscriptionStatus]) {
        return WPSubscriptionStatusOptOut;
    }
    return nil;
}

+ (BOOL) subscriptionStatusIsOptIn {
    return [[self subscriptionStatus] isEqualToString:WPSubscriptionStatusOptIn];
}

@end
