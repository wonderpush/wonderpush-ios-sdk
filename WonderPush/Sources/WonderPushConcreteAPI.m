//
//  WonderPushConcreteAPI.m
//  WonderPush
//
//  Created by Stéphane JAIS on 07/02/2019.
//

#import "WonderPushConcreteAPI.h"
#import "WPConfiguration.h"
#import "WPJsonSyncInstallation.h"
#import "WPLog.h"
#import "WonderPush.h"
#import "WPAPIClient.h"
#import "WPAction.h"
#import "WonderPush_private.h"
#import "WPUtil.h"
#import <UIKit/UIKit.h>
#import "WPInstallationCoreProperties.h"
#import "WPDataManager.h"

@interface WonderPushConcreteAPI (private)
@end

@implementation WonderPushConcreteAPI
- (void) activate {}
- (void) deactivate {}
- (instancetype) init
{
    if (self = [super init]) {
        self.locationManager = [CLLocationManager new];
    }
    return self;
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

- (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    if ([type characterAtIndex:0] != '@') {
        @throw [NSException exceptionWithName:@"illegal argument"
                                       reason:@"This method must only be called for internal events, starting with an '@'"
                                     userInfo:nil];
    }
    
    [self trackEvent:type eventData:data customData:customData];
}
- (void) trackEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData
{
    
    if (![type isKindOfClass:[NSString class]]) return;
    NSString *eventEndPoint = @"/events";
    long long date = [WPUtil getServerDate];
    NSMutableDictionary *params = [[NSMutableDictionary alloc]
                                   initWithDictionary:@{@"type": type,
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
    
    [WonderPush postEventually:eventEndPoint params:@{@"body":params}];
    
}
- (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *)notification
{
    WPLogDebug(@"Running action %@", action);
    NSString *type = [WPUtil stringForKey:@"type" inDictionary:action];
    
    if ([WP_ACTION_TRACK isEqualToString:type]) {
        
        NSDictionary *event = [WPUtil dictionaryForKey:@"event" inDictionary:action] ?: @{};
        NSString *type = [WPUtil stringForKey:@"type" inDictionary:event];
        if (!type) return;
        NSDictionary *custom = [WPUtil dictionaryForKey:@"custom" inDictionary:event];
        [self trackEvent:type
                     eventData:@{@"campaignId": notification[@"c"] ?: [NSNull null],
                                 @"notificationId": notification[@"n"] ?: [NSNull null]}
                    customData:custom];
        
    } else if ([WP_ACTION_UPDATE_INSTALLATION isEqualToString:type]) {
        
        NSNumber *appliedServerSide = [WPUtil numberForKey:@"appliedServerSide" inDictionary:action];
        NSDictionary *installation = [WPUtil dictionaryForKey:@"installation" inDictionary:action];
        NSDictionary *directCustom = [WPUtil dictionaryForKey:@"custom" inDictionary:action];
        if (installation == nil && directCustom != nil) {
            installation = @{@"custom":directCustom};
        }
        if (installation) {
            if ([appliedServerSide isEqual:@YES]) {
                WPLogDebug(@"Received server installation diff: %@", installation);
                [[WPJsonSyncInstallation forCurrentUser] receiveDiff:installation];
            } else {
                WPLogDebug(@"Putting installation diff: %@", installation);
                [[WPJsonSyncInstallation forCurrentUser] put:installation];
            }
        }

    } else if ([WP_ACTION_RESYNC_INSTALLATION isEqualToString:type]) {
        
        void (^cont)(NSDictionary *action) = ^(NSDictionary *action){
            WPLogDebug(@"Running enriched action %@", action);
            NSDictionary *installation = [WPUtil dictionaryForKey:@"installation" inDictionary:action] ?: @{};
            NSNumber *reset = [WPUtil numberForKey:@"reset" inDictionary:action];
            NSNumber *force = [WPUtil numberForKey:@"force" inDictionary:action];
            
            // Take or reset custom
            if ([reset isEqual:@YES]) {
                [[WPJsonSyncInstallation forCurrentUser] receiveState:installation
                                                        resetSdkState:[force isEqual:@YES]];
            } else {
                [[WPJsonSyncInstallation forCurrentUser] receiveServerState:installation];
            }

            [WonderPush refreshPreferencesAndConfiguration];
        };
        
        NSDictionary *installation = [WPUtil dictionaryForKey:@"installation" inDictionary:action];
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
                [WPJsonSyncInstallation flush];
            }];
            
        }
        
    } else if ([WP_ACTION_RATING isEqualToString:type]) {
        
        NSString *itunesAppId = [[NSBundle mainBundle] objectForInfoDictionaryKey:WP_ITUNES_APP_ID];
        if (itunesAppId != nil) {
            [WonderPush openURL:[NSURL URLWithString:[NSString stringWithFormat:ITUNES_APP_URL_FORMAT, itunesAppId]]];
        }
        
    } else  if ([WP_ACTION_METHOD_CALL isEqualToString:type]) {
        
        NSString *methodName = [WPUtil stringForKey:@"method" inDictionary:action];
        id methodParameter = [WPUtil nullsafeObjectForKey:@"methodArg" inDictionary:action];
        NSDictionary *parameters = @{WP_REGISTERED_CALLBACK_PARAMETER_KEY: methodParameter ?: [NSNull null]};
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:methodName object:self userInfo:parameters];
        });
    } else if ([WP_ACTION_LINK isEqualToString:type]) {
        
        NSString *url = [WPUtil stringForKey:@"url" inDictionary:action];
        [WonderPush openURL:[NSURL URLWithString:url]];
        
    } else if ([WP_ACTION_MAP_OPEN isEqualToString:type]) {
        
        NSDictionary *mapData = [WPUtil dictionaryForKey:@"map" inDictionary:notification] ?: @{};
        NSDictionary *place = [WPUtil dictionaryForKey:@"place" inDictionary:mapData] ?: @{};
        NSDictionary *point = [WPUtil dictionaryForKey:@"point" inDictionary:place] ?: @{};
        NSNumber *lat = [WPUtil numberForKey:@"lat" inDictionary:point];
        NSNumber *lon = [WPUtil numberForKey:@"lon" inDictionary:point];
        if (!lat || !lon) return;
        NSString *url = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%f,%f", [lat doubleValue], [lon doubleValue]];
        WPLogDebug(@"url: %@", url);
        [WonderPush openURL:[NSURL URLWithString:url]];
        
    } else if ([WP_ACTION__DUMP_STATE isEqualToString:type]) {
        
        NSDictionary *stateDump = [[WPConfiguration sharedConfiguration] dumpState] ?: @{};
        WPLog(@"STATE DUMP: %@", stateDump);
        [self trackInternalEvent:@"@DEBUG_DUMP_STATE"
                             eventData:nil
                            customData:@{@"ignore_sdkStateDump": stateDump}];
        
    } else if ([WP_ACTION__OVERRIDE_SET_LOGGING isEqualToString:type]) {
        
        NSNumber *force = [WPUtil numberForKey:@"force" inDictionary:action];
        WPLog(@"OVERRIDE setLogging: %@", force);
        [WPConfiguration sharedConfiguration].overrideSetLogging = force;
        if (force != nil) {
            WPLogEnable([force boolValue]);
        }
        
    } else if ([WP_ACTION__OVERRIDE_NOTIFICATION_RECEIPT isEqualToString:type]) {
        
        NSNumber *force = [WPUtil numberForKey:@"force" inDictionary:action];
        WPLog(@"OVERRIDE notification receipt: %@", force);
        [WPConfiguration sharedConfiguration].overrideNotificationReceipt = force;
        
    } else {
        WPLogDebug(@"Unhandled action type %@", type);
    }
}

- (CLLocation *)location
{
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
    NSNull *null = [NSNull null];
    NSDictionary *apple = @{@"apsEnvironment": [WPUtil getEntitlement:@"aps-environment"] ?: null,
                            @"appId": [WPUtil getEntitlement:@"application-identifier"] ?: null,
                            @"backgroundModes": [WPUtil getBackgroundModes] ?: null
                            };
    NSDictionary *application = @{@"version" : [WPInstallationCoreProperties getVersionString] ?: null,
                                  @"sdkVersion": [WPInstallationCoreProperties getSDKVersionNumber] ?: null,
                                  @"apple": apple ?: null
                                  };
    
    NSDictionary *configuration = @{@"timeZone": [WPInstallationCoreProperties getTimezone] ?: null,
                                    @"carrier": [WPInstallationCoreProperties getCarrierName] ?: null,
                                    @"country": [WPInstallationCoreProperties getCountry] ?: null,
                                    @"currency": [WPInstallationCoreProperties getCurrency] ?: null,
                                    @"locale": [WPInstallationCoreProperties getLocale] ?: null};
    
    CGRect screenSize = [WPInstallationCoreProperties getScreenSize];
    NSDictionary *device = @{@"id": [WPUtil deviceIdentifier] ?: null,
                             @"federatedId": [WPUtil federatedId] ? [NSString stringWithFormat:@"0:%@", [WPUtil federatedId]] : null,
                             @"platform": @"iOS",
                             @"osVersion": [WPInstallationCoreProperties getOsVersion] ?: null,
                             @"brand": @"Apple",
                             @"model": [WPInstallationCoreProperties getDeviceModel] ?: null,
                             @"screenWidth": [NSNumber numberWithInt:(int)screenSize.size.width] ?: null,
                             @"screenHeight": [NSNumber numberWithInt:(int)screenSize.size.height] ?: null,
                             @"screenDensity": [NSNumber numberWithInt:(int)[WPInstallationCoreProperties getScreenDensity]] ?: null,
                             @"configuration": configuration,
                             };
    
    NSDictionary *properties = @{@"application": application,
                                 @"device": device
                                 };

    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    [sharedConfiguration setCachedInstallationCoreProperties:properties];
    [sharedConfiguration setCachedInstallationCorePropertiesDate: [NSDate date]];
    [sharedConfiguration setCachedInstallationCorePropertiesAccessToken:sharedConfiguration.accessToken];
    [[WPJsonSyncInstallation forCurrentUser] put:properties];
}

- (void) setNotificationEnabled:(BOOL)enabled
{
    [WPConfiguration sharedConfiguration].notificationEnabled = enabled;
    [WonderPush refreshPreferencesAndConfiguration];

    // Register to push notifications if enabled
    if (enabled) {
        [WPUtil askUserPermission];
    }
}

- (void) sendPreferences
{
    [WonderPush hasAcceptedVisibleNotificationsWithCompletionHandler:^(BOOL osNotificationEnabled) {
        WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
        BOOL enabled = sharedConfiguration.notificationEnabled;
        NSString *value = enabled && osNotificationEnabled ? @"optIn" : @"optOut";

        sharedConfiguration.cachedOsNotificationEnabled = osNotificationEnabled;
        sharedConfiguration.cachedOsNotificationEnabledDate = [NSDate date];

        [[WPJsonSyncInstallation forCurrentUser] put:@{@"preferences": @{
                                                               @"subscriptionStatus": value,
                                                               @"subscribedToNotifications": enabled ? @YES : @NO,
                                                               @"osNotificationVisible": osNotificationEnabled ? @YES : @NO,
                                                               }}];
    }];
}

- (BOOL) getNotificationEnabled
{
    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    return sharedConfiguration.notificationEnabled;
}
- (void) setDeviceToken:(NSString *)deviceToken
{
    if (deviceToken) {
        deviceToken = [deviceToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
        deviceToken = [deviceToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    }

    WPConfiguration *sharedConfiguration = [WPConfiguration sharedConfiguration];
    [sharedConfiguration setDeviceToken:deviceToken];
    [sharedConfiguration setDeviceTokenAssociatedToUserId:sharedConfiguration.userId];
    [sharedConfiguration setCachedDeviceTokenDate:[NSDate date]];
    [sharedConfiguration setCachedDeviceTokenAccessToken:sharedConfiguration.accessToken];
    [[WPJsonSyncInstallation forCurrentUser] put:@{@"pushToken": @{@"data": deviceToken ?: [NSNull null]}}];
}

- (NSString *)accessToken {
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.accessToken;
}


- (NSString *)deviceId {
    return [WPUtil deviceIdentifier];
}


- (NSDictionary *)getInstallationCustomProperties {
    return [([WPUtil dictionaryForKey:@"custom" inDictionary:[WPJsonSyncInstallation forCurrentUser].sdkState] ?: @{}) copy];
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
    [[WPJsonSyncInstallation forCurrentUser] put:@{@"custom":customProperties}];
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


@end
