//
//  WonderPushConcreteAPI.m
//  WonderPush
//
//  Created by Stéphane JAIS on 07/02/2019.
//

#import "WonderPushConcreteAPI.h"
#import "WPConfiguration.h"
#import "WPJsonSyncInstallation.h"
#import <WonderPushCommon/WPLog.h>
#import <WonderPush/WonderPush.h>
#import "WPAPIClient.h"
#import <WonderPush/WPAction.h>
#import "WonderPush_private.h"
#import "WPUtil.h"
#import <WonderPushCommon/WPNSUtil.h>
#import <UIKit/UIKit.h>
#import "WPInstallationCoreProperties.h"
#import "WPDataManager.h"
#import "WPInAppMessaging+Bootstrap.h"
#import <WonderPushCommon/WPReportingData.h>
#import "WPAction_private.h"
#import "WPBlackWhiteList.h"

@interface WonderPushConcreteAPI () <CLLocationManagerDelegate>
@property (atomic, assign) CLAuthorizationStatus locationManagerAuthorizationStatus;
@end

@implementation WonderPushConcreteAPI
- (instancetype)init {
    self = [super init];
    if (self) {
        self.locationManager = [CLLocationManager new];
        self.locationManager.delegate = self;
    }
    return self;
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    self.locationManagerAuthorizationStatus = status;
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (@available(iOS 14.0, *)) {
        self.locationManagerAuthorizationStatus = manager.authorizationStatus;
    } else {
        // Fallback on earlier versions
    }
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void) activate {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WPIAMSDKSettings *settings = [[WPIAMSDKSettings alloc] init];
        settings.loggerMaxCountBeforeReduce = 100;
        settings.loggerSizeAfterReduce = 50;
        settings.loggerInVerboseMode = WPLogEnabled();
        settings.appFGRenderMinIntervalInMinutes = 1; // render at most one message from app-foreground trigger every minute;
        [WPInAppMessaging bootstrapIAMWithSettings:settings];
    });
    [WPInAppMessaging resume];

}

- (void) deactivate {
    [WPInAppMessaging pause];
}

/**
 Makes sure we have an up-to-date device token, and send it to WonderPush servers if necessary.
 */
- (void) refreshDeviceTokenIfPossible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    });
}

- (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback {
    if ([type characterAtIndex:0] != '@') {
        @throw [NSException exceptionWithName:@"illegal argument"
                                       reason:@"This method must only be called for internal events, starting with an '@'"
                                     userInfo:nil];
    }
    
    [self trackEvent:type eventData:data customData:customData sentCallback:sentCallback];
}

- (void)trackInAppEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    [self trackEvent:type eventData:data customData:customData requiresSubscription:NO sentCallback:nil];
}

- (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    [self trackInternalEvent:type eventData:data customData:customData sentCallback:nil];
}

- (void) countInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    if ([type characterAtIndex:0] != '@') {
        @throw [NSException exceptionWithName:@"illegal argument"
                                       reason:@"This method must only be called for internal events, starting with an '@'"
                                     userInfo:nil];
    }
    [self countEvent:type eventData:data customData:customData];
}

- (void) countEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    if (![type isKindOfClass:[NSString class]]) return;

    // Installations that have both an accessToken and the overrideNotificationReceipt are not just counted, they are tracked.
    if (WPConfiguration.sharedConfiguration.accessToken
        && WPConfiguration.sharedConfiguration.overrideNotificationReceipt) {
        [self trackEvent:type eventData:data customData:customData];
        return;
    }
    
    NSDictionary *params = [self paramsForEvent:type eventData:data customData:customData];
    if (!params) return;
    NSDictionary *body = [WPNSUtil dictionaryForKey:@"body" inDictionary:params];
    if (!body) return;

    // Store locally
    NSDictionary *occurrences = nil;
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:body occurrences:&occurrences];

    // Add occurrences to the body
    if (occurrences) {
        NSMutableDictionary *mutableBody = body.mutableCopy;
        mutableBody[@"occurrences"] = occurrences;
        body = [NSDictionary dictionaryWithDictionary:mutableBody];
        NSMutableDictionary *mutableParams = params.mutableCopy;
        mutableParams[@"body"] = body;
        params = [NSDictionary dictionaryWithDictionary:mutableParams];
    }

    // Notify locally
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:WPEventFiredNotification object:nil userInfo:@{
            WPEventFiredNotificationEventTypeKey : type,
            WPEventFiredNotificationEventDataKey : [NSDictionary dictionaryWithDictionary:body],
            WPEventFiredNotificationEventOccurrencesKey : occurrences,
        }];
    });

    // Do not send to the server if blacklisted
    [self eventsBlackWhiteList:^(WPBlackWhiteList *eventsBlackWhiteList, NSError *error) {
        if (eventsBlackWhiteList && ![eventsBlackWhiteList allow:type]) {
            WPLogDebug(@"Event of type %@ forbidden by configuration", type);
            return;
        }

        NSString *eventEndPoint = @"/events";
        WPRequest *request = [WPRequest new];
        request.method = @"POST";
        request.params = params;
        request.userId = WPConfiguration.sharedConfiguration.userId;
        request.resource = eventEndPoint;
        [WonderPush requestEventuallyWithMeasurementsApi:request];
    }];

}

- (NSDictionary *)paramsForEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData {
    long long date = [WPUtil getServerDate];
    NSMutableDictionary *body = [[NSMutableDictionary alloc]
                                   initWithDictionary:@{@"type": type,
                                                        @"actionDate": [NSNumber numberWithLongLong:date]}];
    
    if ([data isKindOfClass:[NSDictionary class]]) {
        [body addEntriesFromDictionary:data];
    }
    
    if ([customData isKindOfClass:[NSDictionary class]]) {
        [body setValue:customData forKey:@"custom"];
    }
    
    if (!body[@"location"]) {
        CLLocation *location = [WonderPush location];
        if (location != nil) {
            body[@"location"] = @{@"lat": [NSNumber numberWithDouble:location.coordinate.latitude],
                                    @"lon": [NSNumber numberWithDouble:location.coordinate.longitude]};
        }
    }

    WPReportingData *reportingData = WonderPush.lastClickedNotificationReportingData;
    [reportingData fillEventDataInto:body attributionReason:WPReportingAttributionReasonRecentNotificationOpened];
    return @{@"body":[body copy]};
}

- (void) trackEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData {
    [self trackEvent:type eventData:data customData:customData sentCallback:nil];
}

- (void) trackEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void(^)(void))sentCallback {
    [self trackEvent:type eventData:data customData:customData requiresSubscription:YES sentCallback:sentCallback];
}
- (void) trackEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData requiresSubscription:(BOOL)requiresSubscription sentCallback:(void(^)(void))sentCallback {
    if (![type isKindOfClass:[NSString class]]) return;
    @synchronized (self) {
        NSString *eventEndPoint = @"/events";
        NSDictionary *params = [self paramsForEvent:type eventData:data customData:customData];
        if (!params) return;
        NSDictionary *body = [WPNSUtil dictionaryForKey:@"body" inDictionary:params];
        if (!body) return;
        
        // Store locally
        NSDictionary *occurrences = nil;
        [WPConfiguration.sharedConfiguration rememberTrackedEvent:body occurrences:&occurrences];

        // Add occurrences to the body
        if (occurrences) {
            NSMutableDictionary *mutableBody = body.mutableCopy;
            mutableBody[@"occurrences"] = occurrences;
            body = [NSDictionary dictionaryWithDictionary:mutableBody];
            NSMutableDictionary *mutableParams = params.mutableCopy;
            mutableParams[@"body"] = body;
            params = [NSDictionary dictionaryWithDictionary:mutableParams];
        }

        // Notify locally
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:WPEventFiredNotification object:nil userInfo:@{
                WPEventFiredNotificationEventTypeKey : type,
                WPEventFiredNotificationEventDataKey : [NSDictionary dictionaryWithDictionary:body],
                WPEventFiredNotificationEventOccurrencesKey : occurrences,
            }];
        });
        
        // Do not send to the server if blacklisted
        [self eventsBlackWhiteList:^(WPBlackWhiteList *eventsBlackWhiteList, NSError *error) {
            if (eventsBlackWhiteList && ![eventsBlackWhiteList allow:type]) {
                WPLogDebug(@"Event of type %@ forbidden by configuration", type);
                return;
            }

            [WonderPush.remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {
                if ([config.data[WP_REMOTE_CONFIG_TRACK_EVENTS_FOR_NON_SUBSCRIBERS] boolValue]) {
                    // Save in request vault
                    [WonderPush postEventually:eventEndPoint params:params];
                    if (sentCallback) sentCallback();
                } else if (requiresSubscription) {
                    [WonderPush safeDeferWithSubscription:^{
                        [WonderPush postEventually:eventEndPoint params:params];
                        if (sentCallback) sentCallback();
                    }];
                } else {
                        WPRequest *request = [WPRequest new];
                        request.method = @"POST";
                        request.params = params;
                        request.resource = @"/events";
                        [WonderPush requestEventuallyWithOptionalAccessToken:request];
                }
            }];
        }];
    }
}

- (void) eventsBlackWhiteList:(void(^)(WPBlackWhiteList * _Nullable, NSError * _Nullable))completion {
    [WonderPush.remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {
        WPBlackWhiteList *list = nil;
        if (config) {
            NSArray<NSString *> *rules = [WPNSUtil arrayForKey:WP_REMOTE_CONFIG_EVENTS_BLACK_WHITE_LIST_KEY inDictionary:config.data ?: @{}];
            if (rules) {
                list = [[WPBlackWhiteList alloc] initWithRules:rules];
            }

        }
        completion(list, error);
    }];
}

- (void) executeAction:(WPAction *)action withReportingData:(WPReportingData *)reportingData attributionReason:(NSString *)reason {
    if (action.targetUrl) {
        [WonderPush openURL:action.targetUrl targetUrlMode:action.targetUrlMode];
    }
    for (WPActionFollowUp *followUp in action.followUps) {
        [self executeActionFollowUp:followUp withReportingData:reportingData attributionReason:reason];
    }
}

- (void) executeActionFollowUp:(WPActionFollowUp *)followUp withReportingData:(WPReportingData *)reportingData attributionReason:(NSString *)reason
{
    WPLogDebug(@"Running followUp %@", followUp);
    @synchronized (self) {
        switch (followUp.type) {
            case WPActionFollowUpTypeTrackEvent: {
                if (!followUp.event) return;
                [self trackEvent:followUp.event
                       eventData:[reportingData filledEventData:@{} attributionReason:reason]
                      customData:followUp.custom];
                
            }
                break;
            case WPActionFollowUpTypeUpdateInstallation: {
                if (followUp.appliedServerSide) {
                    WPLogDebug(@"Received server installation diff: %@", followUp.installation);
                    [[WPJsonSyncInstallation forCurrentUser] receiveDiff:followUp.installation];

                } else {
                    WPLogDebug(@"Putting installation diff: %@", followUp.installation);
                    [[WPJsonSyncInstallation forCurrentUser] put:followUp.installation];
                }
                
            }
                break;
            case WPActionFollowUpTypeAddProperty: {
                if (followUp.custom) {
                    for (id field in followUp.custom) {
                        [WonderPush addProperty:field value:followUp.custom[field]];
                    }
                }
            }
                break;
            case WPActionFollowUpTypeRemoveProperty: {
                if (followUp.custom) {
                    for (id field in followUp.custom) {
                        [WonderPush removeProperty:field value:followUp.custom[field]];
                    }
                }

            }
                break;
            case WPActionFollowUpTypeAddTag:
                [WonderPush addTags:followUp.tags];
                break;
            case WPActionFollowUpTypeSubscribeToNotifications:
                [WonderPush subscribeToNotifications];
                break;
            case WPActionFollowUpTypeRemoveTag:
                [WonderPush removeTags:followUp.tags];
                break;
            case WPActionFollowUpTypeRemoveAllTags:
                [WonderPush removeAllTags];
                break;
            case WPActionFollowUpTypeCloseNotifications: {
                // NOTE: Unlike on Android, this is asynchronous, and almost always resolves after the current notification is displayed
                //       so until we have a completion handler in this method (and many levels up the call hierarchy,
                //       it's not possible to remove all notifications and then display a new one.
                if (@available(iOS 10.0, *)) {
                    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
                        NSMutableArray<NSString *> *ids = [NSMutableArray new];
                        for (UNNotification *notification in notifications) {
                            // Filter tag (notification.request.identifier is never nil, so code is simpler by skipping [NSNull null] handling)
                            NSString *_Nullable tag = followUp.tags.firstObject;
                            if (tag != nil && ![tag isEqualToString:notification.request.identifier]) {
                                continue;
                            }
                            // Filter threadId
                            NSString *_Nullable threadId = followUp.threadId;
                            if (threadId != nil) {
                                if ([@"" isEqualToString:threadId] && !(notification.request.content.threadIdentifier == nil || [@"" isEqualToString:notification.request.content.threadIdentifier])) {
                                    continue;
                                } else if ([threadId isKindOfClass:[NSString class]] && ![threadId isEqualToString:notification.request.content.threadIdentifier]) {
                                    continue;
                                }
                            }
                            // Filter category
                            NSString *_Nullable category = followUp.category;
                            if (category != nil) {
                                if ([@"" isEqualToString:category] && !(notification.request.content.categoryIdentifier == nil || [@"" isEqualToString:notification.request.content.categoryIdentifier])) {
                                    continue;
                                } else if ([category isKindOfClass:[NSString class]] && ![category isEqualToString:notification.request.content.categoryIdentifier]) {
                                    continue;
                                }
                            }
                            // Filter targetContentId
                            if (@available(iOS 13.0, *)) {
                                NSString *_Nullable targetContentId = followUp.targetContentId;
                                if (targetContentId != nil) {
                                    if ([@"" isEqualToString:targetContentId] && !(notification.request.content.targetContentIdentifier == nil || [@"" isEqualToString:notification.request.content.targetContentIdentifier])) {
                                        continue;
                                    } else if ([targetContentId isKindOfClass:[NSString class]] && ![targetContentId isEqualToString:notification.request.content.targetContentIdentifier]) {
                                        continue;
                                    }
                                }
                            }

                            [ids addObject:notification.request.identifier];
                        }
                        [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:[ids copy]];
                    }];
                }
            }
                break;
            case WPActionFollowUpTypeResyncInstallation: {
                void (^cont)(WPActionFollowUp *) = ^(WPActionFollowUp *followUp){
                    WPLogDebug(@"Running followUp %@", followUp);
                    // Take or reset custom
                    if (followUp.reset) {
                        [[WPJsonSyncInstallation forCurrentUser] receiveState:followUp.installation
                                                                resetSdkState:followUp.force];
                    } else {
                        [[WPJsonSyncInstallation forCurrentUser] receiveServerState:followUp.installation];
                    }
                    
                    [WonderPush refreshPreferencesAndConfiguration];
                };
                
                if (followUp.installation) {
                    cont(followUp);
                } else {
                    WPLogDebug(@"Fetching installation for followUp %@", followUp);
                    [WonderPush get:@"/installation" params:nil handler:^(WPResponse *response, NSError *error) {
                        if (error) {
                            WPLog(@"Failed to fetch installation for running followUp %@: %@", followUp, error);
                            return;
                        }
                        if (![response.object isKindOfClass:[NSDictionary class]]) {
                            WPLog(@"Failed to fetch installation for running followUp %@, got: %@", followUp, response.object);
                            return;
                        }
                        NSMutableDictionary *installation = [(NSDictionary *)response.object mutableCopy];
                        // Filter other fields starting with _ like _serverTime and _serverTook
                        [installation removeObjectsForKeys:[installation.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                            return [evaluatedObject isKindOfClass:[NSString class]] && [(NSString*)evaluatedObject hasPrefix:@"_"];
                        }]]];
                        followUp.installation = [NSDictionary dictionaryWithDictionary:installation];
                        cont(followUp);
                        // We added async processing, we need to ensure that we flush it too, especially in case we're running receiveActions in the background
                        [WPJsonSyncInstallation flush];
                    }];
                }
            }
                break;
            case WPActionFollowUpTypeRating: {
                NSString *itunesAppId = [[NSBundle mainBundle] objectForInfoDictionaryKey:WP_ITUNES_APP_ID];
                if (itunesAppId != nil) {
                    [WonderPush openURL:[NSURL URLWithString:[NSString stringWithFormat:ITUNES_APP_URL_FORMAT, itunesAppId]] targetUrlMode:nil];
                }
            }
                break;
            case WPActionFollowUpTypeMethod: {
                NSDictionary *parameters = @{
                                             WP_REGISTERED_CALLBACK_METHOD_KEY: followUp.methodName ?: [NSNull null],
                                             WP_REGISTERED_CALLBACK_PARAMETER_KEY: followUp.methodArg ?: [NSNull null],
                                             };
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:followUp.methodName object:self userInfo:parameters]; // @FIXME Deprecated, remove in v4.0.0
                    [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_REGISTERED_CALLBACK object:self userInfo:parameters];
                });
            }
                break;
            case WPActionFollowUpTypeMapOpen: {
                NSNumber *lat = followUp.latitude;
                NSNumber *lon = followUp.longitude;
                if (!lat || !lon) return;
                NSString *url = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%f,%f", [lat doubleValue], [lon doubleValue]];
                WPLogDebug(@"url: %@", url);
                [WonderPush openURL:[NSURL URLWithString:url] targetUrlMode:nil];
            }
                break;
            case WPActionFollowUpTypeDumpState: {
                NSDictionary *stateDump = [[WPConfiguration sharedConfiguration] dumpState] ?: @{};
                WPLog(@"STATE DUMP: %@", stateDump);
                [self trackInternalEvent:@"@DEBUG_DUMP_STATE"
                               eventData:nil
                              customData:@{@"ignore_sdkStateDump": stateDump}];
                
            }
                break;
            case WPActionFollowUpTypeOverrideSetLogging: {
                WPLog(@"OVERRIDE setLogging: %@", followUp.force ? @"YES" : @"NO");
                [WPConfiguration sharedConfiguration].overrideSetLogging = [NSNumber numberWithBool:followUp.force];
                if (followUp.force) WPLogEnable(true);
            }
                break;
            case WPActionFollowUpTypeOverrideNotificationReceipt: {
                WPLog(@"OVERRIDE notification receipt: %@", followUp.force ? @"YES" : @"NO");
                [WPConfiguration sharedConfiguration].overrideNotificationReceipt = [NSNumber numberWithBool:followUp.force];
            }
                break;
            default:
                WPLogDebug(@"Unhandled followUp %@", followUp);
                break;
        }
    }
}

- (void) triggerLocationPrompt
{
    NSString *alwaysDescription = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"];

    if (alwaysDescription) {
        [self.locationManager requestAlwaysAuthorization];
    } else if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        WPLog(@"Location prompt requested but usage string not found in Info.plist. Please set NSLocationAlwaysUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription or NSLocationWhenInUseUsageDescription in your Info.plist file");
    }
}

- (CLLocation *)location
{
    CLAuthorizationStatus status = self.locationManagerAuthorizationStatus;
    if (status != kCLAuthorizationStatusAuthorizedAlways
        && status != kCLAuthorizationStatusAuthorizedWhenInUse) {
        return nil;
    }
    CLLocation *location = self.locationManager.location;
    if (   !location // skip if unavailable
        || [location.timestamp timeIntervalSinceNow] < -300 // skip if older than 5 minutes
        || location.horizontalAccuracy < 0 // skip invalid locations
        || location.horizontalAccuracy > 10000 // skip if less precise then 10 km
        ) {
        return nil;
    }
    return location;

}
- (void) updateInstallationCoreProperties
{
    @synchronized (self) {
        NSNull *null = [NSNull null];
        NSDictionary *apple = @{@"apsEnvironment": [WPUtil getEntitlement:@"aps-environment"] ?: null,
                                @"appId": [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleIdentifierKey] ?: null, // NOTE: We're missing the Team ID to have a full App ID, but adding the App ID requires the developer to modify Info.plist
                                @"backgroundModes": [WPUtil getBackgroundModes] ?: null,
                                @"notificationServiceExtension": [WPUtil getNotificationServiceExtensionDict],
                                };
        NSDictionary *application = @{@"version" : [WPInstallationCoreProperties getVersionString] ?: null,
                                      @"sdkVersion": [WPInstallationCoreProperties getSDKVersionNumber] ?: null,
                                      @"integrator": [WonderPush getIntegrator] ?: null,
                                      @"apple": apple ?: null
                                      };
        
        NSDictionary *configuration = @{@"timeZone": [WPInstallationCoreProperties getTimezone] ?: null,
                                        @"timeOffset": [WPInstallationCoreProperties getTimeOffset] ?: null,
                                        @"carrier": [WPInstallationCoreProperties getCarrierName] ?: null,
                                        @"country": [WPInstallationCoreProperties getCountry] ?: null,
                                        @"currency": [WPInstallationCoreProperties getCurrency] ?: null,
                                        @"locale": [WPInstallationCoreProperties getLocale] ?: null};
        
        CGRect screenSize = [WPInstallationCoreProperties getScreenSize];
        NSDictionary *device = @{@"id": [WPUtil deviceIdentifier] ?: null,
                                 @"platform": @"iOS",
                                 @"osVersion": [WPInstallationCoreProperties getOsVersion] ?: null,
                                 @"brand": @"Apple",
                                 @"category": @"mobile",
                                 @"model": [WPInstallationCoreProperties getDeviceModel] ?: null,
                                 @"screenWidth": [NSNumber numberWithInt:(int)screenSize.size.width] ?: null,
                                 @"screenHeight": [NSNumber numberWithInt:(int)screenSize.size.height] ?: null,
                                 @"screenDensity": [NSNumber numberWithInt:(int)[WPInstallationCoreProperties getScreenDensity]] ?: null,
                                 @"configuration": configuration,
                                 };
        
        NSDictionary *properties = @{@"application": application,
                                     @"device": device
                                     };
        
        [[WPJsonSyncInstallation forCurrentUser] put:properties];
    }
}

- (void) setNotificationEnabled:(BOOL)enabled
{
    [WPConfiguration sharedConfiguration].notificationEnabled = enabled;
    [WonderPush refreshPreferencesAndConfigurationSync:!enabled]; // when disabling, we use a sync flow to ensure we can withdraw user consent synchronously right after we return

    // Register to push notifications if enabled
    if (enabled) {
        [WPUtil askUserPermission];
    }
}

- (void) sendPreferences
{
    [self sendPreferencesSync:NO];
}

- (void) sendPreferencesSync:(BOOL)sync
{
    void (^handler)(BOOL osNotificationsEnable) = ^(BOOL osNotificationsEnabled) {
        WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
        BOOL enabled = sharedConfiguration.notificationEnabled;
        NSString *subscriptionStatus = enabled && osNotificationsEnabled ? WPSubscriptionStatusOptIn : WPSubscriptionStatusOptOut;

        sharedConfiguration.cachedOsNotificationEnabled = osNotificationsEnabled;
        sharedConfiguration.cachedOsNotificationEnabledDate = [NSDate date];

        WPJsonSyncInstallation *installation = [WPJsonSyncInstallation forCurrentUser];
        NSString *oldSubscriptionStatus = [WonderPush subscriptionStatus];
        [installation put:@{@"preferences": @{
                                    @"subscriptionStatus": subscriptionStatus,
                                    @"subscribedToNotifications": enabled ? @YES : @NO,
                                    @"osNotificationsVisible": osNotificationsEnabled ? @YES : @NO,
        }}];
        if (![subscriptionStatus isEqualToString:oldSubscriptionStatus]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter
                 postNotificationName:WPSubscriptionStatusChangedNotification
                 object:subscriptionStatus
                 userInfo:oldSubscriptionStatus ? @{
                    WPSubscriptionStatusChangedNotificationPreviousStatusInfoKey : oldSubscriptionStatus,
                } : nil];
            });
        }
    };

    if (sync) {
        WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
        handler(sharedConfiguration.cachedOsNotificationEnabled);
    } else {
        [WonderPush hasAcceptedVisibleNotificationsWithCompletionHandler:handler];
    }
}

- (BOOL) getNotificationEnabled
{
    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    return sharedConfiguration.notificationEnabled;
}
- (void) setDeviceToken:(NSString *)deviceToken
{
    @synchronized (self) {
        WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
        [sharedConfiguration setDeviceToken:deviceToken];
        [sharedConfiguration setDeviceTokenAssociatedToUserId:sharedConfiguration.userId];
        [sharedConfiguration setCachedDeviceTokenDate:[NSDate date]];
        [sharedConfiguration setCachedDeviceTokenAccessToken:sharedConfiguration.accessToken];
        [[WPJsonSyncInstallation forCurrentUser] put:@{@"pushToken": @{@"data": deviceToken ?: [NSNull null]}}];
    }
}

- (NSString *)accessToken {
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.accessToken;
}


- (NSString *)deviceId {
    return [WPUtil deviceIdentifier];
}


- (NSDictionary *)getInstallationCustomProperties {
    @synchronized (self) {
        NSDictionary *customProperties = [([WPNSUtil dictionaryForKey:@"custom" inDictionary:[WPJsonSyncInstallation forCurrentUser].sdkState] ?: @{}) copy];
        NSMutableDictionary *rtn = [NSMutableDictionary new];
        for (id key in customProperties) {
            if ([key isKindOfClass:[NSString class]] && [(NSString *)key containsString:@"_"]) {
                rtn[key] = customProperties[key];
            }
        }
        return [NSDictionary dictionaryWithDictionary:rtn];
    }
}


- (NSString *)installationId {
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.installationId;
}


- (NSString *)pushToken {
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.deviceToken;
}


- (void)putInstallationCustomProperties:(NSDictionary *)customProperties {
    @synchronized (self) {
        NSMutableDictionary *diff = [NSMutableDictionary new];
        for (id key in customProperties ?: @{}) {
            if ([key isKindOfClass:[NSString class]] && [(NSString *)key containsString:@"_"]) {
                diff[key] = customProperties[key];
            } else {
                WPLog(@"Dropping an installation property with no prefix: %@", key);
            }
        }
        [[WPJsonSyncInstallation forCurrentUser] put:@{@"custom":[diff copy]}];
    }
}


- (void)trackEvent:(NSString *)type {
    [self trackEvent:type eventData:nil customData:nil];
}


- (void)trackEvent:(NSString *)type withData:(NSDictionary *)data {
    [self trackEvent:type eventData:nil customData:data];
}

- (void)clearAllData {
    [[WPDataManager sharedInstance] clearAllData];
}


- (void)clearEventsHistory {
    [[WPDataManager sharedInstance] clearEventsHistory];
}


- (void)clearPreferences {
    [[WPDataManager sharedInstance] clearPreferences];
}


- (void)downloadAllData:(void (^)(NSData *, NSError *))completion {
    [[WPDataManager sharedInstance] downloadAllData:completion];
}


- (NSDictionary *)getProperties {
    return [self getInstallationCustomProperties];
}


- (void) setProperty:(NSString *)field value:(id)value {
    if (field == nil) return;
    [self putProperties:@{field: value ?: [NSNull null]}];
}


- (void) unsetProperty:(NSString *)field {
    if (field == nil) return;
    [self putProperties:@{field: [NSNull null]}];
}


- (void) addProperty:(NSString *)field value:(id)value {
    if (field == nil || value == nil || value == [NSNull null]) return;
    @synchronized (self) {
        // The contract is to actually append new values only, not shuffle or deduplicate everything,
        // hence the array and the set.
        NSMutableArray *values = [NSMutableArray arrayWithArray:[self getPropertyValues:field]];
        NSMutableSet *set = [NSMutableSet setWithArray:values];
        NSArray *inputs = [value isKindOfClass:[NSArray class]] ? value : @[value];
        for (id input in inputs) {
            if (input == nil || input == [NSNull null]) continue;
            if ([set containsObject:input]) continue;
            [values addObject:input];
            [set addObject:input];
        }
        [self setProperty:field value:[values copy]];
    }
}


- (void) removeProperty:(NSString *)field value:(id)value {
    if (field == nil || value == nil) return; // Note: We accept removing NSNull.
    @synchronized (self) {
        // The contract is to actually remove every listed values (all duplicated appearences), not shuffle or deduplicate everything else
        NSMutableArray *values = [NSMutableArray arrayWithArray:[self getPropertyValues:field]];
        NSArray *inputs = [value isKindOfClass:[NSArray class]] ? value : @[value];
        [values removeObjectsInArray:inputs];
        [self setProperty:field value:[values copy]];
    }
}


- (id) getPropertyValue:(NSString *)field {
    if (field == nil) return [NSNull null];
    @synchronized (self) {
        NSDictionary *properties = [self getProperties];
        id rtn = properties[field];
        if ([rtn isKindOfClass:[NSArray class]]) {
            rtn = [rtn count] > 0 ? [rtn objectAtIndex:0] : nil;
        }
        if (rtn == nil) rtn = [NSNull null];
        return rtn;
    }
}


- (NSArray *) getPropertyValues:(NSString *)field {
    if (field == nil) return @[];
    @synchronized (self) {
        NSDictionary *properties = [self getProperties];
        id rtn = properties[field];
        if (rtn == nil || rtn == [NSNull null]) rtn = @[];
        if (![rtn isKindOfClass:[NSArray class]]) {
            rtn = @[rtn];
        }
        return rtn;
    }
}


- (BOOL)isSubscribedToNotifications {
    return [self getNotificationEnabled];
}


- (void)putProperties:(NSDictionary *)properties {
    return [self putInstallationCustomProperties:properties];
}


- (void)subscribeToNotifications {
    return [self setNotificationEnabled:YES];
}


- (void)trackEvent:(NSString *)eventType attributes:(NSDictionary *)attributes {
    return [self trackEvent:eventType eventData:nil customData:attributes];
}


- (void)unsubscribeFromNotifications {
    return [self setNotificationEnabled:NO];
}

- (void) addTag:(NSString *)tag {
    [self addTags:@[tag]];
}

- (void) addTags:(NSArray<NSString *> *)newTags {
    if (newTags == nil || [newTags count] == 0) return;
    @synchronized(self) {
        NSMutableOrderedSet<NSString *> *tags = [NSMutableOrderedSet orderedSetWithOrderedSet:[self getTags]];
        for (NSString *tag in newTags) {
            if (![tag isKindOfClass:[NSString class]] || [tag length] == 0) continue;
            [tags addObject:tag];
        }
        [[WPJsonSyncInstallation forCurrentUser] put:@{@"custom":@{@"tags":[tags array]}}];
    }
}

- (void) removeTag:(NSString *)tag {
    [self removeTags:@[tag]];
}

- (void) removeTags:(NSArray<NSString *> *)oldTags {
    if (oldTags == nil || [oldTags count] == 0) return;
    @synchronized(self) {
        NSMutableOrderedSet<NSString *> *tags = [NSMutableOrderedSet orderedSetWithOrderedSet:[self getTags]];
        for (NSString *tag in oldTags) {
            if (![tag isKindOfClass:[NSString class]]) continue;
            [tags removeObject:tag];
        }
        [[WPJsonSyncInstallation forCurrentUser] put:@{@"custom":@{@"tags":[tags array]}}];
    }
}

- (void) removeAllTags {
    [[WPJsonSyncInstallation forCurrentUser] put:@{@"custom":@{@"tags":[NSNull null]}}];
}

- (NSOrderedSet<NSString *> *) getTags {
    @synchronized(self) {
        NSDictionary *custom = [([WPNSUtil dictionaryForKey:@"custom" inDictionary:[WPJsonSyncInstallation forCurrentUser].sdkState] ?: @{}) copy];
        NSArray *tags = [WPNSUtil arrayForKey:@"tags" inDictionary:custom];
        if (tags == nil) {
            // Recover from a potential scalar string value
            if ([custom[@"tags"] isKindOfClass:[NSString class]]) {
                tags = @[custom[@"tags"]];
            } else {
                tags = @[];
            }
        }
        
        NSMutableOrderedSet<NSString *> *rtn = [NSMutableOrderedSet new]; // use a sorted implementation to avoid useless diffs later on
        for (id tag in tags) {
            if (![tag isKindOfClass:[NSString class]] || [tag length] == 0) continue;
            [rtn addObject:tag];
        }
        return [NSOrderedSet orderedSetWithOrderedSet:rtn];
    }
}

- (bool) hasTag:(NSString *)tag {
    if (tag == nil) return NO;
    @synchronized (self) {
        return [[self getTags] containsObject:tag];
    }
}

@end
