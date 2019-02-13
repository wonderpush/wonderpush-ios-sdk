//
//  WonderPushConcreteAPI.m
//  WonderPush
//
//  Created by Stéphane JAIS on 07/02/2019.
//

#import "WonderPushConcreteAPI.h"
#import "WPConfiguration.h"
#import "WPJsonSyncInstallationCustom.h"
#import "WPLog.h"
#import "WonderPush.h"
#import "WPAPIClient.h"
#import "WPAction.h"
#import "NSDictionary+TypeSafe.h"
#import "WonderPush_private.h"
#import "WPUtil.h"
#import <UIKit/UIKit.h>
#import "WPInstallationCoreProperties.h"
#import "WPDataManager.h"

@interface WonderPushConcreteAPI (private)
/**
 Updates or add properties to the current installation
 @param properties a collection of properties to add
 @param overwrite if true all the installation will be cleaned before update
 */
- (void) updateInstallation:(NSDictionary *)properties shouldOverwrite:(BOOL)overwrite;
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
    if (![self isRegisteredForRemoteNotifications]) return;
    if (@available(iOS 8.0, *)) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)]) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else {
            WPLog(@"Cannot resolve registerForRemoteNotifications");
        }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:[[UIApplication sharedApplication] enabledRemoteNotificationTypes]];
#pragma clang diagnostic pop
    }
}

/**
 Whether iOS has granted a device token (or should have, for iOS 7).
 */
- (BOOL) isRegisteredForRemoteNotifications
{
    if (@available(iOS 8.0, *)) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
            return [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
        } else {
            WPLog(@"Cannot resolve isRegisteredForRemoteNotifications");
            return NO;
        }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != 0;
#pragma clang diagnostic pop
    }
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
    NSString *type = [action stringForKey:@"type"];
    
    if ([WP_ACTION_TRACK isEqualToString:type]) {
        
        NSDictionary *event = [action dictionaryForKey:@"event"] ?: @{};
        NSString *type = [event stringForKey:@"type"];
        if (!type) return;
        NSDictionary *custom = [event dictionaryForKey:@"custom"];
        [self trackEvent:type
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
                [[WPJsonSyncInstallationCustom forCurrentUser] receiveState:custom
                                                              resetSdkState:[force isEqual:@YES]];
            } else {
                [[WPJsonSyncInstallationCustom forCurrentUser] receiveServerState:custom];
            }
            
            // Refresh core properties
            conf.cachedInstallationCoreProperties = @{};
            [self updateInstallationCoreProperties];
            
            // Refresh push token
            id oldDeviceToken = conf.deviceToken;
            conf.deviceToken = nil;
            [self setDeviceToken:oldDeviceToken];
            
            // Refresh preferences
            if (conf.notificationEnabled) {
                [self updateInstallation:@{@"preferences":@{@"subscriptionStatus":@"optIn"}}
                         shouldOverwrite:NO];
            } else {
                [self updateInstallation:@{@"preferences":@{@"subscriptionStatus":@"optOut"}}
                         shouldOverwrite:NO];
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
            [WonderPush openURL:[NSURL URLWithString:[NSString stringWithFormat:ITUNES_APP_URL_FORMAT, itunesAppId]]];
        }
        
    } else  if ([WP_ACTION_METHOD_CALL isEqualToString:type]) {
        
        NSString *methodName = [action stringForKey:@"method"];
        id methodParameter = [action nullsafeObjectForKey:@"methodArg"];
        NSDictionary *parameters = @{WP_REGISTERED_CALLBACK_PARAMETER_KEY: methodParameter ?: [NSNull null]};
        [[NSNotificationCenter defaultCenter] postNotificationName:methodName object:self userInfo:parameters];
        
    } else if ([WP_ACTION_LINK isEqualToString:type]) {
        
        NSString *url = [action stringForKey:@"url"];
        [WonderPush openURL:[NSURL URLWithString:url]];
        
    } else if ([WP_ACTION_MAP_OPEN isEqualToString:type]) {
        
        NSDictionary *mapData = [notification dictionaryForKey:@"map"] ?: @{};
        NSDictionary *place = [mapData dictionaryForKey:@"place"] ?: @{};
        NSDictionary *point = [place dictionaryForKey:@"point"] ?: @{};
        NSNumber *lat = [point numberForKey:@"lat"];
        NSNumber *lon = [point numberForKey:@"lon"];
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
        
        NSNumber *force = [action numberForKey:@"force"];
        WPLog(@"OVERRIDE setLogging: %@", force);
        [WPConfiguration sharedConfiguration].overrideSetLogging = force;
        if (force != nil) {
            WPLogEnable([force boolValue]);
        }
        
    } else if ([WP_ACTION__OVERRIDE_NOTIFICATION_RECEIPT isEqualToString:type]) {
        
        NSNumber *force = [action numberForKey:@"force"];
        WPLog(@"OVERRIDE notification receipt: %@", force);
        [WPConfiguration sharedConfiguration].overrideNotificationReceipt = force;
        
    } else {
        WPLogDebug(@"Unhandled action type %@", type);
    }
}
- (void) updateInstallation:(NSDictionary *)properties shouldOverwrite:(BOOL)overwrite
{
    if (!overwrite && (![properties isKindOfClass:[NSDictionary class]] || !properties.count)) return;
    NSString *installationEndPoint = @"/installation";
    [WonderPush postEventually:installationEndPoint params:@{@"body":properties, @"overwrite":[NSNumber numberWithBool:overwrite]}];
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
- (void) setNotificationEnabled:(BOOL)enabled
{
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
        [WPUtil registerToPushNotifications];
    }
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

- (NSString *)accessToken {
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    return configuration.accessToken;
}


- (NSString *)deviceId {
    return [WPUtil deviceIdentifier];
}


- (NSDictionary *)getInstallationCustomProperties {
    return [[WPJsonSyncInstallationCustom forCurrentUser].sdkState copy];
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
    [[WPJsonSyncInstallationCustom forCurrentUser] put:customProperties];

}


- (void)trackEvent:(NSString *)type {
    [self trackEvent:type eventData:nil customData:nil];
}


- (void)trackEvent:(NSString *)type withData:(NSDictionary *)data {
    [self trackEvent:type eventData:nil customData:data];
}

- (void)clearAllData {
    // TODO: code me
}


- (void)clearEventsHistory {
    // TODO: code me
}


- (void)clearPreferences {
    // TODO: code me
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
