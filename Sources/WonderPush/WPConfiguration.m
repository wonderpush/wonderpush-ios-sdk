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

#import "WPConfiguration.h"
#import "WonderPush_private.h"
#import <WonderPushCommon/WPLog.h>
#import <WonderPushCommon/WPJsonUtil.h>
#import "WPRequestVault.h"
#import "WPUtil.h"
#import "WPJsonSyncLiveActivity.h"
#import <WonderPushCommon/WPNSUtil.h>

static WPConfiguration *sharedConfiguration = nil;

@interface WPConfiguration ()

@property (nonatomic, strong) NSDate * (^now)(void);

@property (nonatomic, strong) NSString *accessToken;

@property (nonatomic, strong) NSNumber *_notificationEnabled;

- (void) rememberTrackedEvent:(NSDictionary *)eventParams now:(NSDate *)now;

@end

@implementation WPConfiguration

@synthesize accessToken = _accessToken;
@synthesize deviceToken = _deviceToken;
@synthesize sid = _sid;
@synthesize userId = _userId;
@synthesize installationId = _installationId;
@synthesize _notificationEnabled = __notificationEnabled;
@synthesize timeOffset = _timeOffset;
@synthesize timeOffsetPrecision = _timeOffsetPrecision;
@synthesize justOpenedNotification = _justOpenedNotification;


+ (void) initialize
{
    sharedConfiguration = [[self alloc] init];
    sharedConfiguration.maximumUncollapsedTrackedEventsCount = DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_COUNT;
    sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs = DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_AGE_MS;
    sharedConfiguration.maximumCollapsedOtherTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_OTHER_TRACKED_EVENTS_COUNT;
    sharedConfiguration.maximumCollapsedLastCustomTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_LAST_CUSTOM_TRACKED_EVENTS_COUNT;
    sharedConfiguration.maximumCollapsedLastBuiltinTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_LAST_BUILTIN_TRACKED_EVENTS_COUNT;
}

+ (WPConfiguration *) sharedConfiguration
{
    return sharedConfiguration;
}


#pragma mark - Utilities

- (NSDictionary *) _getNSDictionaryFromJSONForKey:(NSString *)key
{
    id rawValue = [[NSUserDefaults standardUserDefaults] valueForKey:key];
    if (!rawValue) return nil;
    if ([rawValue isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)rawValue;
    } else if ([rawValue isKindOfClass:[NSData class]]) {
        NSError *error = NULL;
        NSDictionary *value = [NSJSONSerialization JSONObjectWithData:(NSData *)rawValue options:kNilOptions error:&error];
        if (error) WPLog(@"WPConfiguration: Error while deserializing %@: %@", key, error);
        return value;
    }
    WPLog(@"WPConfiguration: Expected an NSDictionary of JSON NSData but got: (%@) %@, for key %@", [rawValue class], rawValue, key);
    return nil;
}

- (NSArray *) _getNSArrayFromJSONForKey:(NSString *)key
{
    id rawValue = [[NSUserDefaults standardUserDefaults] valueForKey:key];
    if (!rawValue) return nil;
    if ([rawValue isKindOfClass:[NSArray class]]) {
        return (NSArray *)rawValue;
    } else if ([rawValue isKindOfClass:[NSData class]]) {
        NSError *error = NULL;
        NSArray *value = [NSJSONSerialization JSONObjectWithData:(NSData *)rawValue options:kNilOptions error:&error];
        if (error) WPLog(@"WPConfiguration: Error while deserializing %@: %@", key, error);
        return value;
    }
    WPLog(@"WPConfiguration: Expected an NSArray of JSON NSData but got: (%@) %@, for key %@", [rawValue class], rawValue, key);
    return nil;
}

- (void) _setNSDictionaryAsJSON:(NSDictionary *)value forKey:(NSString *)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (value) {
        @try {
            NSError *error = NULL;
            NSData *data = [NSJSONSerialization dataWithJSONObject:value options:kNilOptions error:&error];
            if (error) WPLog(@"WPConfiguration: Error while serializing %@: %@", key, error);
            else [defaults setValue:data forKeyPath:key];
        } @catch (id exception) {
            WPLog(@"WPConfiguration: Error while serializing %@: %@", key, exception);
        }
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];
}

- (void) _setNSArrayAsJSON:(NSArray *)value forKey:(NSString *)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (value) {
        NSError *error = NULL;
        @try {
            NSData *data = [NSJSONSerialization dataWithJSONObject:value options:kNilOptions error:&error];
            if (error) WPLog(@"WPConfiguration: Error while serializing %@: %@", key, error);
            else [defaults setValue:data forKeyPath:key];
        } @catch (NSException *exception) {
            WPLog(@"Error serializing event: %@", exception);
        }
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];
}

- (NSDate *) _getNSDateForKey:(NSString *)key
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:key];
}

- (void) _setNSDate:(NSDate *)value forKey:(NSString *)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (value) {
        [defaults setValue:value forKeyPath:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];
}

- (NSString *) _getNSStringForKey:(NSString *)key
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:key];
}

- (void) _setNSString:(NSString *)value forKey:(NSString *)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (value) {
        [defaults setValue:value forKeyPath:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];
}

- (NSNumber *) _getNSNumberForKey:(NSString *)key
{
    id value = [[NSUserDefaults standardUserDefaults] valueForKey:key];
    if (![value isKindOfClass:[NSNumber class]]) value = nil;
    return (NSNumber *)value;
}

- (void) _setNSNumber:(NSNumber *)value forKey:(NSString *)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (value) {
        [defaults setValue:value forKeyPath:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];
}

- (NSDictionary *) dumpState
{
    NSMutableDictionary *rtn = [NSMutableDictionary new];
    [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key hasPrefix:@"_wonderpush"] || [key hasPrefix:@"__wonderpush"]) {
            rtn[key] = [WPJsonUtil ensureJSONEncodable:obj];
        }
    }];
    return [NSDictionary dictionaryWithDictionary:rtn];
}


#pragma mark - JSON utilities

- (id) _NSDateToJSON:(NSDate *)date
{
    if (!date) return [NSNull null];
    return [NSNumber numberWithLongLong:(long long)([date timeIntervalSince1970] * 1000)];
}

- (NSDate *) _JSONToNSDate:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        if ([value longLongValue] == INT_MAX) {
            WPLogDebug(@"Returning nil date instead of 2038-01-19T03:14:07Z (INT_MAX)");
            // Previous version of -[WPConfiguration _NSDateToJSON:] gave INT_MAX for any reasonable dates
            return nil;
        }
        return [NSDate dateWithTimeIntervalSince1970:([(NSNumber *)value longLongValue]/1000)];
    }
    return nil;
}

- (NSNumber *) _BOOLToJSON:(BOOL)value
{
    return value == YES ? @YES : @NO;
}

- (BOOL) _JSONToBOOL:(id)value withDefault:(BOOL)defaultValue
{
    if (!value || value == [NSNull null]) return defaultValue;
    if ([value isEqual:@YES]) return YES;
    return NO;
}

- (id) _NSStringToJSON:(NSString *)value
{
    return value ?: [NSNull null];
}

- (NSString *) _JSONToNSString:(id)value
{
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (id) _NSDictionaryToJSON:(NSDictionary *)value
{
    return value ?: [NSNull null];
}

- (id) _NSArrayToJSON:(NSArray *)value
{
    return value ?: [NSNull null];
}

- (NSDictionary *) _JSONToNSDictionary:(id)value
{
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

- (NSArray *) _JSONToNSArray:(id)value
{
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

#pragma mark - User consent
- (BOOL) userConsent
{
    return [[self _getNSNumberForKey:USER_DEFAULTS_USER_CONSENT_KEY] boolValue];
}
- (void) setUserConsent:(BOOL)userConsent
{
    [self _setNSNumber:[NSNumber numberWithBool:userConsent] forKey:USER_DEFAULTS_USER_CONSENT_KEY];
}
#pragma mark - Change user id

- (void) changeUserId:(NSString *)newUserId
{
    if ([@"" isEqualToString:newUserId]) newUserId = nil;
    if ((newUserId == nil && self.userId == nil)
        || (newUserId != nil && [newUserId isEqualToString:self.userId])) {
        // No userId change
        return;
    }
    // Save current user preferences
    NSDictionary *currentUserArchive = @{
                                         USER_DEFAULTS_ACCESS_TOKEN_KEY: [self _NSStringToJSON:self.accessToken],
                                         USER_DEFAULTS_SID_KEY: [self _NSStringToJSON:self.sid],
                                         USER_DEFAULTS_INSTALLATION_ID: [self _NSStringToJSON:self.installationId],
                                         USER_DEFAULTS_USER_ID_KEY: [self _NSStringToJSON:self.userId],
                                         USER_DEFAULTS_NOTIFICATION_ENABLED_KEY: [self _BOOLToJSON:self.notificationEnabled],
                                         USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_KEY: [self _BOOLToJSON:self.cachedOsNotificationEnabled],
                                         USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_DATE_KEY: [self _NSDateToJSON:self.cachedOsNotificationEnabledDate],
                                         USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN: [self _NSDictionaryToJSON:self.cachedInstallationCustomPropertiesWritten],
                                         USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN_DATE: [self _NSDateToJSON:self.cachedInstallationCustomPropertiesWrittenDate],
                                         USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED: [self _NSDictionaryToJSON:self.cachedInstallationCustomPropertiesUpdated],
                                         USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED_DATE: [self _NSDateToJSON:self.cachedInstallationCustomPropertiesUpdatedDate],
                                         USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_FIRST_DELAYED_WRITE_DATE: [self _NSDateToJSON:self.cachedInstallationCustomPropertiesFirstDelayedWriteDate],
                                         USER_DEFAULTS_LAST_INTERACTION_DATE: [self _NSDateToJSON:self.lastInteractionDate],
                                         USER_DEFAULTS_LAST_APP_OPEN_DATE: [self _NSDateToJSON:self.lastAppOpenDate],
                                         USER_DEFAULTS_LAST_APP_OPEN_INFO: [self _NSDictionaryToJSON:self.lastAppOpenInfo],
                                         USER_DEFAULTS_LAST_APP_OPEN_SENT_DATE: [self _NSDateToJSON:self.lastAppOpenSentDate],
                                         USER_DEFAULTS_COUNTRY: [self _NSStringToJSON:self.country],
                                         USER_DEFAULTS_CURRENCY: [self _NSStringToJSON:self.currency],
                                         USER_DEFAULTS_LOCALE: [self _NSStringToJSON:self.locale],
                                         USER_DEFAULTS_TIME_ZONE: [self _NSStringToJSON:self.timeZone],
                                         USER_DEFAULTS_TRACKED_EVENTS_KEY: [self _NSArrayToJSON:self.trackedEvents],
                                         };
    NSMutableDictionary *usersArchive = [([self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY] ?: @{}) mutableCopy];
    usersArchive[self.userId ?: @""] = currentUserArchive;
    [self _setNSDictionaryAsJSON:[usersArchive copy] forKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY];

    // Load new user preferences
    NSDictionary *newUserArchive = usersArchive[newUserId ?: @""] ?: @{};
    self.userId              = newUserId;
    self.accessToken         = [self _JSONToNSString:newUserArchive[USER_DEFAULTS_ACCESS_TOKEN_KEY]];
    self.sid                 = [self _JSONToNSString:newUserArchive[USER_DEFAULTS_SID_KEY]];
    self.installationId      = [self _JSONToNSString:newUserArchive[USER_DEFAULTS_INSTALLATION_ID]];
    self.notificationEnabled = [self _JSONToBOOL:    newUserArchive[USER_DEFAULTS_NOTIFICATION_ENABLED_KEY] withDefault:YES];
    self.cachedOsNotificationEnabled                             = [self _JSONToBOOL:        newUserArchive[USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_KEY] withDefault:NO];
    self.cachedOsNotificationEnabledDate                         = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_DATE_KEY]];
    self.cachedInstallationCustomPropertiesWritten               = [self _JSONToNSDictionary:newUserArchive[USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN]];
    self.cachedInstallationCustomPropertiesWrittenDate           = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN_DATE]];
    self.cachedInstallationCustomPropertiesUpdated               = [self _JSONToNSDictionary:newUserArchive[USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED]];
    self.cachedInstallationCustomPropertiesUpdatedDate           = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED_DATE]];
    self.cachedInstallationCustomPropertiesFirstDelayedWriteDate = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_FIRST_DELAYED_WRITE_DATE]];
    self.lastInteractionDate = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_LAST_INTERACTION_DATE]];
    self.lastAppOpenDate     = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_LAST_APP_OPEN_DATE]];
    self.lastAppOpenInfo     = [self _JSONToNSDictionary:newUserArchive[USER_DEFAULTS_LAST_APP_OPEN_INFO]];
    self.lastAppOpenSentDate    = [self _JSONToNSDate:      newUserArchive[USER_DEFAULTS_LAST_APP_OPEN_SENT_DATE]];
    self.country             = [self _JSONToNSString:    newUserArchive[USER_DEFAULTS_COUNTRY]];
    self.currency            = [self _JSONToNSString:    newUserArchive[USER_DEFAULTS_CURRENCY]];
    self.locale              = [self _JSONToNSString:    newUserArchive[USER_DEFAULTS_LOCALE]];
    self.timeZone            = [self _JSONToNSString:    newUserArchive[USER_DEFAULTS_TIME_ZONE]];
    self.trackedEvents       = [self _JSONToNSArray:     newUserArchive[USER_DEFAULTS_TRACKED_EVENTS_KEY]];
}

// Uses @"" for nil userId
- (NSArray *) listKnownUserIds
{
    NSDictionary *usersArchive = [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY] ?: @{};
    NSMutableArray *mutable = [[NSMutableArray alloc] initWithArray:[usersArchive allKeys]];
    if (![mutable containsObject:self.userId ?: @""]) {
        [mutable addObject:self.userId ?: @""];
    }
    return [[NSArray alloc] initWithArray:mutable];
}


#pragma mark - Access token

- (NSURL *) baseURL
{
    return [NSURL URLWithString:PRODUCTION_API_URL];
}

- (NSString *) accessToken
{
    @synchronized (self) {
        if (_accessToken)
            return _accessToken;

        _accessToken = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_ACCESS_TOKEN_KEY];
        return _accessToken;
    }
}

- (NSString *) deviceToken
{
    @synchronized (self) {
        if (_deviceToken)
            return _deviceToken;

        _deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_DEVICE_TOKEN_KEY];
        return _deviceToken;
    }
}

- (void) setDeviceToken:(NSString *)deviceToken
{
    @synchronized (self) {
        if (![deviceToken isEqual:_deviceToken]) {
            WPLogDebug(@"Setting device token: %@", deviceToken);
        }
        _deviceToken = deviceToken;
        [self _setNSString:deviceToken forKey:USER_DEFAULTS_DEVICE_TOKEN_KEY];
    }
}

- (NSDate *) cachedDeviceTokenDate
{
    return [self _getNSDateForKey:USER_DEFAULTS_CACHED_DEVICE_TOKEN_DATE];
}

- (void) setCachedDeviceTokenDate:(NSDate *)cachedDeviceTokenDate
{
    [self _setNSDate:cachedDeviceTokenDate forKey:USER_DEFAULTS_CACHED_DEVICE_TOKEN_DATE];
}

- (NSString *) deviceTokenAssociatedToUserId
{
    return [self _getNSStringForKey:USER_DEFAULTS_DEVICE_TOKEN_ASSOCIATED_TO_USER_ID_KEY];
}

- (void) setDeviceTokenAssociatedToUserId:(NSString *)userId
{
    [self _setNSString:userId forKey:USER_DEFAULTS_DEVICE_TOKEN_ASSOCIATED_TO_USER_ID_KEY];
}

- (NSString *) cachedDeviceTokenAccessToken
{
    return [self _getNSStringForKey:USER_DEFAULTS_CACHED_DEVICE_TOKEN_ACCESS_TOKEN_KEY];
}

- (void) setCachedDeviceTokenAccessToken:(NSString *)cachedDeviceTokenAccessToken
{
    [self _setNSString:cachedDeviceTokenAccessToken forKey:USER_DEFAULTS_CACHED_DEVICE_TOKEN_ACCESS_TOKEN_KEY];
}


- (void) setAccessToken:(NSString *)accessToken
{
    @synchronized (self) {
        _accessToken = accessToken;
        WPLogDebug(@"Setting access token: %@", accessToken);
        [self _setNSString:accessToken forKey:USER_DEFAULTS_ACCESS_TOKEN_KEY];
    }
}

- (void) setStoredClientId:(NSString *)clientId
{
    @synchronized (self) {
        if (clientId) {
            [self _setNSString:clientId forKey:USER_DEFAULTS_CLIENT_ID_KEY];
        }
    }
}

- (NSString *) getStoredClientId
{
    @synchronized (self) {
        return [self _getNSStringForKey:USER_DEFAULTS_CLIENT_ID_KEY];
    }
}

- (NSString *) getAccessTokenForUserId:(NSString *)userId
{
    if (((userId == nil || [userId isEqualToString:@""]) && self.userId == nil)
        || (userId != nil && [userId isEqualToString:self.userId])) {
        return self.accessToken;
    } else {
        NSDictionary *usersArchive = [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY] ?: @{};
        NSDictionary *userArchive = usersArchive[userId ?: @""] ?: @{};
        return [self _JSONToNSString:userArchive[USER_DEFAULTS_ACCESS_TOKEN_KEY]];
    }
}


#pragma mark - DEVICE ID

- (NSString *) deviceId
{
    @synchronized (self) {
        return [self _getNSStringForKey:USER_DEFAULTS_DEVICE_ID_KEY];
    }
}

- (void) setDeviceId:(NSString *)deviceId
{
    @synchronized (self) {
        [self _setNSString:deviceId forKey:USER_DEFAULTS_DEVICE_ID_KEY];
    }
}


#pragma mark - INSTALLATION ID

- (NSString *) installationId
{
    @synchronized (self) {
        if (_installationId)
            return _installationId;

        _installationId = [self _getNSStringForKey:USER_DEFAULTS_INSTALLATION_ID];
        return _installationId;
    }
}

- (void) setInstallationId:(NSString *)installationId
{
    @synchronized (self) {
        _installationId = installationId;
        WPLogDebug(@"Setting installationId: %@", installationId);
        [self _setNSString:installationId forKey:USER_DEFAULTS_INSTALLATION_ID];
    }
}


#pragma mark - USER ID

- (NSString *) userId
{
    @synchronized (self) {
        if (_userId)
            return _userId;
        _userId = [self _getNSStringForKey:USER_DEFAULTS_USER_ID_KEY];
        return _userId;
    }
}

- (void) setUserId:(NSString *)userId
{
    @synchronized (self) {
        if ([@"" isEqualToString:userId]) {
            userId = nil;
        }
        _userId = userId;
        WPLogDebug(@"Setting userId: %@", userId);
        [self _setNSString:userId forKey:USER_DEFAULTS_USER_ID_KEY];
    }
}


#pragma mark - SID

- (NSString *)sid
{
    @synchronized (self) {
        if (_sid)
            return _sid;

        _sid = [self _getNSStringForKey:USER_DEFAULTS_SID_KEY];
        return _sid;
    }
}

- (void) setSid:(NSString *)sid
{
    @synchronized (self) {
        _sid = sid;
        WPLogDebug(@"Setting sid: %@", sid);
        [self _setNSString:sid forKey:USER_DEFAULTS_SID_KEY];
    }
}

- (BOOL) usesSandbox
{
    return [[self.baseURL absoluteString] rangeOfString:PRODUCTION_API_URL].location == NSNotFound;
}


#pragma mark - NOTIFICATION ENABLED

- (BOOL) notificationEnabled
{
    @synchronized (self) {
        if (!__notificationEnabled) {
            __notificationEnabled = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_NOTIFICATION_ENABLED_KEY];
            if (__notificationEnabled == nil) {
                return YES;
            }
        }
        return [__notificationEnabled boolValue];
    }
}

- (void) setNotificationEnabled:(BOOL)notificationEnabled
{
    @synchronized (self) {
        __notificationEnabled = [NSNumber numberWithBool:notificationEnabled];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setValue:__notificationEnabled forKey:USER_DEFAULTS_NOTIFICATION_ENABLED_KEY];
        [defaults synchronize];
    }
}

- (BOOL) cachedOsNotificationEnabled
{
    @synchronized (self) {
        NSNumber *value = [self _getNSNumberForKey:USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_KEY];
        if (value == nil) return YES; // although it's not opt-in by default on iOS, that's how the related installation field works
        return [value boolValue];
    }
}

- (void) setCachedOsNotificationEnabled:(BOOL)cachedOsNotificationEnabled
{
    @synchronized (self) {
        [self _setNSNumber:[NSNumber numberWithBool:cachedOsNotificationEnabled] forKey:USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_KEY];
    }
}

- (NSDate *) cachedOsNotificationEnabledDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_DATE_KEY];
    }
}

- (void) setCachedOsNotificationEnabledDate:(NSDate *)cachedOsNotificationEnabledDate
{
    @synchronized (self) {
        [self _setNSDate:cachedOsNotificationEnabledDate forKey:USER_DEFAULTS_CACHED_OS_NOTIFICATION_ENABLED_DATE_KEY];
    }
}


#pragma mark - OVERRIDE SET LOGGING

- (NSNumber *) overrideSetLogging
{
    @synchronized (self) {
        return [self _getNSNumberForKey:USER_DEFAULTS_OVERRIDE_SET_LOGGING_KEY];
    }
}

- (void) setOverrideSetLogging:(NSNumber *)overrideSetLogging
{
    @synchronized (self) {
        [self _setNSNumber:overrideSetLogging forKey:USER_DEFAULTS_OVERRIDE_SET_LOGGING_KEY];
    }
}


#pragma mark - OVERRIDE NOTIFICATION RECEIPT

- (NSNumber *) overrideNotificationReceipt
{
    @synchronized (self) {
        return [self _getNSNumberForKey:USER_DEFAULTS_OVERRIDE_NOTIFICATION_RECEIPT_KEY];
    }
}

- (void) setOverrideNotificationReceipt:(NSNumber *)overrideNotificationReceipt
{
    @synchronized (self) {
        [self _setNSNumber:overrideNotificationReceipt forKey:USER_DEFAULTS_OVERRIDE_NOTIFICATION_RECEIPT_KEY];
    }
}


#pragma mark - QUEUED NOTIFICATIONS

- (void) addToQueuedNotifications:(NSDictionary *)notification
{
    @synchronized (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        NSMutableArray *queuedNotifications = [[self getQueuedNotifications] mutableCopy];
        [queuedNotifications addObject:notification];
        NSError *error = NULL;
        NSData *queuedNotificationsData = [NSJSONSerialization dataWithJSONObject:[queuedNotifications copy] options:0 error:&error];
        if (error) {
            WPLogDebug(@"Error while serializing queued notifications: %@", error);
            return;
        }
        NSString *queuedNotificationsJson = [[NSString alloc] initWithData:queuedNotificationsData encoding:NSUTF8StringEncoding];

        [defaults setObject:queuedNotificationsJson forKey:USER_DEFAULTS_QUEUED_NOTIFICATIONS];
        [defaults synchronize];
    }
}

- (NSArray *) getQueuedNotifications
{
    @synchronized (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        NSString *queuedNotificationsJson = [defaults stringForKey:USER_DEFAULTS_QUEUED_NOTIFICATIONS];
        if (queuedNotificationsJson != nil) {
            NSData *queuedNotificationsData = [queuedNotificationsJson dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = NULL;
            id queuedNotifications = [NSJSONSerialization JSONObjectWithData:queuedNotificationsData options:NSJSONReadingMutableContainers error:&error];
            if (error) {
                WPLogDebug(@"Error while reading queued notifications: %@", error);
            }
            if (queuedNotifications) {
                return [NSArray arrayWithArray:queuedNotifications];
            }
        }
        return [NSArray new];
    }
}

- (void) clearQueuedNotifications
{
    @synchronized (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:USER_DEFAULTS_QUEUED_NOTIFICATIONS];
        [defaults synchronize];
    }
}

#pragma mark - CACHED INSTALLATION CUSTOM PROPERTIES

- (NSDictionary *) cachedInstallationCustomPropertiesWritten
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN];
    }
}

- (void) setCachedInstallationCustomPropertiesWritten:(NSDictionary *)cachedInstallationCustomPropertiesWritten
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:cachedInstallationCustomPropertiesWritten forKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN];
    }
}

- (NSDate *) cachedInstallationCustomPropertiesWrittenDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN_DATE];
    }
}

- (void) setCachedInstallationCustomPropertiesWrittenDate:(NSDate *)cachedInstallationCustomPropertiesWrittenDate
{
    @synchronized (self) {
        [self _setNSDate:cachedInstallationCustomPropertiesWrittenDate forKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN_DATE];
    }
}

- (NSDictionary *) cachedInstallationCustomPropertiesUpdated
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED];
    }
}

- (void) setCachedInstallationCustomPropertiesUpdated:(NSDictionary *)cachedInstallationCustomPropertiesUpdated
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:cachedInstallationCustomPropertiesUpdated forKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED];
    }
}

- (NSDate *) cachedInstallationCustomPropertiesUpdatedDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED_DATE];
    }
}

- (void) setCachedInstallationCustomPropertiesUpdatedDate:(NSDate *)cachedInstallationCustomPropertiesUpdatedDate
{
    @synchronized (self) {
        [self _setNSDate:cachedInstallationCustomPropertiesUpdatedDate forKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED_DATE];
    }
}

- (NSDate *) cachedInstallationCustomPropertiesFirstDelayedWriteDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_FIRST_DELAYED_WRITE_DATE];
    }
}

- (void) setCachedInstallationCustomPropertiesFirstDelayedWriteDate:(NSDate *)cachedInstallationCustomPropertiesFirstDelayedWriteDate
{
    @synchronized (self) {
        [self _setNSDate:cachedInstallationCustomPropertiesFirstDelayedWriteDate forKey:USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_FIRST_DELAYED_WRITE_DATE];
    }
}

- (NSDate *) lastReceivedNotificationDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_LAST_RECEIVED_NOTIFICATION_DATE];
    }
}

- (void) setLastReceivedNotificationDate:(NSDate *)lastReceivedNotificationDate
{
    @synchronized (self) {
        [self _setNSDate:lastReceivedNotificationDate forKey:USER_DEFAULTS_LAST_RECEIVED_NOTIFICATION_DATE];
    }
}

- (NSDictionary *) lastReceivedNotification
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_LAST_RECEIVED_NOTIFICATION];
    }
}

- (void) setLastReceivedNotification:(NSDictionary *)lastReceivedNotification
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:lastReceivedNotification forKey:USER_DEFAULTS_LAST_RECEIVED_NOTIFICATION];
    }
}

- (NSDate *) lastOpenedNotificationDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_LAST_OPENED_NOTIFICATION_DATE];
    }
}

- (void) setLastOpenedNotificationDate:(NSDate *)lastOpenedNotificationDate
{
    @synchronized (self) {
        [self _setNSDate:lastOpenedNotificationDate forKey:USER_DEFAULTS_LAST_OPENED_NOTIFICATION_DATE];
    }
}

- (NSDictionary *) lastOpenedNotification
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_LAST_OPENED_NOTIFICATION];
    }
}

- (void) setLastOpenedNotification:(NSDictionary *)lastOpenedNotification
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:lastOpenedNotification forKey:USER_DEFAULTS_LAST_OPENED_NOTIFICATION];
    }
}

- (NSDate *) lastInteractionDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_LAST_INTERACTION_DATE];
    }
}

- (void) setLastInteractionDate:(NSDate *)lastInteractionDate
{
    @synchronized (self) {
        [self _setNSDate:lastInteractionDate forKey:USER_DEFAULTS_LAST_INTERACTION_DATE];
    }
}

- (NSDictionary *) lastAppOpenInfo
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_LAST_APP_OPEN_INFO];
    }
}

- (void) setLastAppOpenInfo:(NSDictionary *)lastAppOpenInfo
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:lastAppOpenInfo forKey:USER_DEFAULTS_LAST_APP_OPEN_INFO];
    }
}

- (NSDate *) lastAppOpenDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_LAST_APP_OPEN_DATE];
    }
}

- (void) setLastAppOpenDate:(NSDate *)lastAppOpenDate
{
    @synchronized (self) {
        [self _setNSDate:lastAppOpenDate forKey:USER_DEFAULTS_LAST_APP_OPEN_DATE];
    }
}

- (NSDate *) lastAppOpenSentDate
{
    @synchronized (self) {
        return [self _getNSDateForKey:USER_DEFAULTS_LAST_APP_OPEN_SENT_DATE];
    }
}

- (void) setLastAppOpenSentDate:(NSDate *)lastAppOpenSentDate
{
    @synchronized (self) {
        [self _setNSDate:lastAppOpenSentDate forKey:USER_DEFAULTS_LAST_APP_OPEN_SENT_DATE];
    }
}

- (NSString *) country
{
    @synchronized (self) {
        return [self _getNSStringForKey:USER_DEFAULTS_COUNTRY];
    }
}

- (void) setCountry:(NSString *)country
{
    @synchronized (self) {
        [self _setNSString:country forKey:USER_DEFAULTS_COUNTRY];
    }
}

- (NSString *) currency
{
    @synchronized (self) {
        return [self _getNSStringForKey:USER_DEFAULTS_CURRENCY];
    }
}

- (void) setCurrency:(NSString *)currency
{
    @synchronized (self) {
        [self _setNSString:currency forKey:USER_DEFAULTS_CURRENCY];
    }
}

- (NSString *) locale
{
    @synchronized (self) {
        return [self _getNSStringForKey:USER_DEFAULTS_LOCALE];
    }
}

- (void) setLocale:(NSString *)locale
{
    @synchronized (self) {
        [self _setNSString:locale forKey:USER_DEFAULTS_LOCALE];
    }
}

- (NSString *) timeZone
{
    @synchronized (self) {
        return [self _getNSStringForKey:USER_DEFAULTS_TIME_ZONE];
    }
}

- (void) setTimeZone:(NSString *)timeZone
{
    @synchronized (self) {
        [self _setNSString:timeZone forKey:USER_DEFAULTS_TIME_ZONE];
    }
}

- (NSDictionary *) installationCustomSyncStatePerUserId
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_INSTALLATION_CUSTOM_SYNC_STATE_PER_USER_ID_KEY];

    }
}

- (void) setInstallationCustomSyncStatePerUserId:(NSDictionary *)installationCustomSyncStatePerUserId
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:installationCustomSyncStatePerUserId forKey:USER_DEFAULTS_INSTALLATION_CUSTOM_SYNC_STATE_PER_USER_ID_KEY];
    }
}

- (NSDictionary *) installationCoreSyncStatePerUserId
{
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_INSTALLATION_CORE_SYNC_STATE_PER_USER_ID_KEY];
    }
}

- (void) setInstallationCoreSyncStatePerUserId:(NSDictionary *)installationCoreSyncStatePerUserId
{
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:installationCoreSyncStatePerUserId forKey:USER_DEFAULTS_INSTALLATION_CORE_SYNC_STATE_PER_USER_ID_KEY];
    }
}

- (void) clearStorageKeepUserConsent:(BOOL)keepUserConsent keepDeviceId:(BOOL)keepDeviceId
{
    @synchronized (self) {
        NSArray *prefixes = @[@"_wonderpush", @"__wonderpush"];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [[defaults dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            BOOL hasPrefix = NO;
            for (NSString *prefix in prefixes) {
                hasPrefix = [key hasPrefix:prefix];
                if (hasPrefix) break;
            }
            if (!hasPrefix) return;

            if (keepUserConsent && [key isEqualToString:USER_DEFAULTS_USER_CONSENT_KEY]) return;
            if (keepDeviceId && [key isEqualToString:USER_DEFAULTS_DEVICE_ID_KEY]) return;
            [defaults removeObjectForKey:key];
        }];
        [defaults synchronize];

        _accessToken = nil;
        _deviceToken = nil;
        _sid = nil;
        _userId = nil;
        _installationId = nil;
        __notificationEnabled = nil;
        _timeOffset = 0;
        _timeOffsetPrecision = 0;
        _justOpenedNotification = nil;
    }
}

- (void)rememberTrackedEvent:(NSDictionary *)eventParams {
    [self rememberTrackedEvent:eventParams now: self.now ? self.now() : [NSDate date]];
}

- (NSArray *)removeExcessEventsFromStart:(NSArray *)list max:(NSInteger) max {
    NSInteger excessEvents = list.count - max;
    if (excessEvents < 0) excessEvents = 0;
    return [list subarrayWithRange:NSMakeRange(excessEvents, list.count - excessEvents)];
}

- (void) rememberTrackedEvent:(NSDictionary *)eventParams now:(NSDate *)nowDate {
    [self rememberTrackedEvent:eventParams occurrences:nil now:nowDate];
}

- (void) rememberTrackedEvent:(NSDictionary *)eventParams occurrences:(NSDictionary **)occurrences {
    [self rememberTrackedEvent:eventParams occurrences:occurrences now:self.now ? self.now() : [NSDate date]];
}

- (void) rememberTrackedEvent:(NSDictionary *)eventParams occurrences:(NSDictionary **)occurrencesOut now:(NSDate *)nowDate {
    if (!eventParams) return;

    NSInteger allTime = 0;

    // Note: It is assumed that the given event is more recent than any other already stored events
    NSString *type = eventParams[@"type"];
    if (!type) return;

    NSString *campaignId = eventParams[@"campaignId"];
    NSString *collapsing = eventParams[@"collapsing"];

    NSArray *oldTrackedEvents = self.trackedEvents;
    uint uncollapsedEventsEstimate = 0; // collapsing == null
    uint collapsedLastBuiltinEventsEstimate = 0; // collapsing.equals("last") && type.startsWith("@")
    uint collapsedLastCustomEventsEstimate = 0; // collapsing.equals("last") && !type.startsWith("@")
    uint collapsedOtherEventsEstimate = 0; // collapsing != null && !collapsing.equals("last") // ie.
    for (NSDictionary *oldTrackedEvent in oldTrackedEvents) {
        NSString *oldTrackedEventCollapsing = oldTrackedEvent[@"collapsing"];
        NSString *oldTrackedEventType = oldTrackedEvent[@"type"];
        if (!oldTrackedEventCollapsing) {
            uncollapsedEventsEstimate++;
        } else if ([@"last" isEqualToString:oldTrackedEventCollapsing]) {
            if ([oldTrackedEventType hasPrefix:@"@"]) {
                collapsedLastBuiltinEventsEstimate++;
            } else {
                collapsedLastCustomEventsEstimate++;
            }
        } else {
            collapsedOtherEventsEstimate++;
        }
    }

    NSMutableArray *uncollapsedEvents = [[NSMutableArray alloc] initWithCapacity:uncollapsedEventsEstimate + 1]; // collapsing == null
    NSMutableArray *collapsedLastBuiltinEvents = [[NSMutableArray alloc] initWithCapacity:collapsedLastBuiltinEventsEstimate + 1]; // collapsing.equals("last") && type.startsWith("@")
    NSMutableArray *collapsedLastCustomEvents = [[NSMutableArray alloc] initWithCapacity:collapsedLastCustomEventsEstimate + 1]; // collapsing.equals("last") && !type.startsWith("@")
    NSMutableArray *collapsedOtherEvents  = [[NSMutableArray alloc] initWithCapacity:collapsedOtherEventsEstimate + 1]; // collapsing != null && !collapsing.equals("last") // ie. collapsing.equals("campaign"), as of this writing

    NSInteger now = nowDate.timeIntervalSince1970 * 1000;
    NSInteger getMaximumUncollapsedTrackedEventsAgeMs = self.maximumUncollapsedTrackedEventsAgeMs;
    for (NSDictionary *oldTrackedEvent in oldTrackedEvents) {
        NSString *oldTrackedEventCollapsing = oldTrackedEvent[@"collapsing"];
        NSString *oldTrackedEventType = oldTrackedEvent[@"type"];
        // Filter out the collapsing=last event of the same type as the new event we want to add
        if ((!collapsing || [@"last" isEqualToString:collapsing])
            && [@"last" isEqualToString:oldTrackedEventCollapsing]
            && [type isEqualToString:oldTrackedEventType]) {
            allTime = MAX(1, oldTrackedEvent[@"occurrences"] && oldTrackedEvent[@"occurrences"][@"allTime"] ? [oldTrackedEvent[@"occurrences"][@"allTime"] integerValue] : 1);
            continue;
        }
        // Filter out the collapsing=campaign event of the same type and campaign as the new event we want to add
        if (campaignId
            && [@"campaign" isEqualToString:collapsing]
            && [@"campaign" isEqualToString:oldTrackedEventCollapsing]
            && [type isEqualToString:oldTrackedEventType]
            && [campaignId isEqualToString:oldTrackedEvent[@"campaignId"]]) {
            allTime = MAX(1, oldTrackedEvent[@"occurrences"] && oldTrackedEvent[@"occurrences"][@"allTime"] ? [oldTrackedEvent[@"occurrences"][@"allTime"] integerValue] : 1);
            continue;
        }
        // Filter out old uncollapsed events
        NSInteger oldTrackedEventActionDate = oldTrackedEvent[@"actionDate"] ? [oldTrackedEvent[@"actionDate"] integerValue] : now;
        if (!oldTrackedEventCollapsing && now - oldTrackedEventActionDate >= getMaximumUncollapsedTrackedEventsAgeMs) {
            continue;
        }
        // TODO We may want to filter out old collapsing=campaign (or any non-null value other than "last") events too
        // Store the event in the proper, per-collapsing list
        if (!oldTrackedEventCollapsing) {
            [uncollapsedEvents addObject:oldTrackedEvent];
        } else if ([@"last" isEqualToString:oldTrackedEventCollapsing]) {
            if ([oldTrackedEventType hasPrefix:@"@"]) {
                [collapsedLastBuiltinEvents addObject:oldTrackedEvent];
            } else {
                [collapsedLastCustomEvents addObject:oldTrackedEvent];
            }
        } else {
            [collapsedOtherEvents addObject:oldTrackedEvent];
        }
    }
    oldTrackedEvents = nil; // let GC collect this

    // Add the new event, uncollapsed
    NSMutableDictionary *uncollapsedEventData;
    NSMutableDictionary *collapsedEventData;
    if (!collapsing) {
        NSError *error = nil;
        // Let make a deep copy by serializing / deserializing to/from JSON
        NSData *data = [NSJSONSerialization dataWithJSONObject:eventParams options:0 error:&error];
        uncollapsedEventData = error ? nil : [[NSJSONSerialization JSONObjectWithData:data options:0 error:&error] mutableCopy];
        if (error) {
            WPLog(@"Could not store uncollapsed tracked event: %@", error);
        } else {
            NSNumber *actionDateNumber = uncollapsedEventData[@"actionDate"] ?: @(now);
            NSInteger actionDate = actionDateNumber.integerValue;
            // Only add uncollapsed if it's not too old
            if (now - actionDate < getMaximumUncollapsedTrackedEventsAgeMs) {
                [uncollapsedEvents addObject:uncollapsedEventData];
            }
        }
    }

    // Add the new event with collapsing
    // We default to collapsing=last, but we otherwise keep any existing collapsing
    {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:eventParams options:0 error:&error];
        collapsedEventData = error ? nil : [[NSJSONSerialization JSONObjectWithData:data options:0 error:&error] mutableCopy];
        if (error) {
            WPLog(@"Could not store collapsed tracked event: %@", error);
        } else {
            allTime += 1;
            if (!collapsing) {
                collapsedEventData[@"collapsing"] = @"last";
                collapsing = @"last";
            }
            if ([@"last" isEqualToString:collapsing]) {
                if ([type hasPrefix:@"@"]) {
                    [collapsedLastBuiltinEvents addObject:collapsedEventData];
                } else {
                    [collapsedLastCustomEvents addObject:collapsedEventData];
                }
            } else {
                [collapsedOtherEvents addObject:collapsedEventData];
            }
        }
    }

    // Sort events by date
    NSComparator comparator = ^(id o1, id o2) {
        NSInteger delta = (o1[@"actionDate"] ? [o1[@"actionDate"] integerValue] : -1)
        - (o2[@"actionDate"] ? [o2[@"actionDate"] integerValue] : -1);
        if (delta < 0) return NSOrderedAscending;
        if (delta > 0) return NSOrderedDescending;
        return NSOrderedSame;
    };
    uncollapsedEvents = [[uncollapsedEvents sortedArrayUsingComparator:comparator] mutableCopy];
    collapsedLastBuiltinEvents = [[collapsedLastBuiltinEvents sortedArrayUsingComparator:comparator] mutableCopy];
    collapsedLastCustomEvents = [[collapsedLastCustomEvents sortedArrayUsingComparator:comparator] mutableCopy];
    collapsedOtherEvents = [[collapsedOtherEvents sortedArrayUsingComparator:comparator] mutableCopy];

    // Impose a limit on the maximum number of tracked events
    uncollapsedEvents = [[self removeExcessEventsFromStart:uncollapsedEvents max:self.maximumUncollapsedTrackedEventsCount] mutableCopy];
    collapsedLastBuiltinEvents = [[self removeExcessEventsFromStart:collapsedLastBuiltinEvents max:self.maximumCollapsedLastBuiltinTrackedEventsCount] mutableCopy];
    collapsedLastCustomEvents = [[self removeExcessEventsFromStart:collapsedLastCustomEvents max:self.maximumCollapsedLastCustomTrackedEventsCount] mutableCopy];
    collapsedOtherEvents = [[self removeExcessEventsFromStart:collapsedOtherEvents max:self.maximumCollapsedOtherTrackedEventsCount] mutableCopy];

    // Compute occurrences
    NSMutableDictionary *occurrences = [NSMutableDictionary new];
    NSInteger last1days=0, last3days=0, last7days=0, last15days=0, last30days=0, last60days=0, last90days=0;

    // Reconstruct the whole list
    NSMutableArray *storeTrackedEvents = [NSMutableArray new];
    for (NSDictionary *e in collapsedLastBuiltinEvents) [storeTrackedEvents addObject:e];
    for (NSDictionary *e in collapsedLastCustomEvents) [storeTrackedEvents addObject:e];
    for (NSDictionary *e in collapsedOtherEvents) [storeTrackedEvents addObject:e];
    NSInteger uncollapsedCount = 0;
    for (NSDictionary *e in uncollapsedEvents) {
        [storeTrackedEvents addObject:e];
        if ([e[@"type"] isEqualToString:type]) {
            ++uncollapsedCount;
            NSNumber *actionDate = e[@"actionDate"] ?: @(now);
            NSInteger numberOfDaysSinceNow = floor((now - actionDate.integerValue) / 86400000);
            if (numberOfDaysSinceNow <= 1) ++last1days;
            if (numberOfDaysSinceNow <= 3) ++last3days;
            if (numberOfDaysSinceNow <= 7) ++last7days;
            if (numberOfDaysSinceNow <= 15) ++last15days;
            if (numberOfDaysSinceNow <= 30) ++last30days;
            if (numberOfDaysSinceNow <= 60) ++last60days;
            if (numberOfDaysSinceNow <= 90) ++last90days;
        }
    }
    uncollapsedEvents = nil; // let GC collect this
    collapsedLastBuiltinEvents = nil; // let GC collect this
    collapsedLastCustomEvents = nil; // let GC collect this
    collapsedOtherEvents = nil; // let GC collect this

    occurrences[@"allTime"] = @(MAX(uncollapsedCount, allTime));
    occurrences[@"last1days"] = @(last1days);
    occurrences[@"last3days"] = @(last3days);
    occurrences[@"last7days"] = @(last7days);
    occurrences[@"last15days"] = @(last15days);
    occurrences[@"last30days"] = @(last30days);
    occurrences[@"last60days"] = @(last60days);
    occurrences[@"last90days"] = @(last90days);

    [collapsedEventData setObject:occurrences forKey:@"occurrences"];
    [uncollapsedEventData setObject:occurrences forKey:@"occurrences"];

    // Store the new list
    [self setTrackedEvents:storeTrackedEvents];

    if (occurrencesOut != nil) *occurrencesOut = [NSDictionary dictionaryWithDictionary:occurrences];
}

- (NSArray *)trackedEvents {
    NSArray *storedTrackedEvents = [self _getNSArrayFromJSONForKey:USER_DEFAULTS_TRACKED_EVENTS_KEY];
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[storedTrackedEvents count]];
    for (NSInteger i = 0; storedTrackedEvents && i < storedTrackedEvents.count; i++) {
        id event = [storedTrackedEvents objectAtIndex:i];
        if (!event[@"creationDate"] && event[@"actionDate"]) {
            NSMutableDictionary *event2 = [event mutableCopy];
            event2[@"creationDate"] = event2[@"actionDate"];
            [result addObject:event2];
        } else {
            [result addObject:event];
        }
    }
    return result;
}

- (void)setTrackedEvents:(NSArray *)trackedEvents {
    @synchronized (self) {
        [self _setNSArrayAsJSON:trackedEvents forKey:USER_DEFAULTS_TRACKED_EVENTS_KEY];
    }
}

- (NSDictionary *) liveActivitySyncStatePerActivityId {
    @synchronized (self) {
        return [self _getNSDictionaryFromJSONForKey:USER_DEFAULTS_LIVE_ACTIVITY_SYNC_STATE_PER_ACTIVITY_ID_KEY];
    }
}

- (void) setLiveActivitySyncStatePerActivityId:(NSDictionary *)liveActivitySyncStatePerActivityId {
    // Filter out any destroyed items
    liveActivitySyncStatePerActivityId = [liveActivitySyncStatePerActivityId dictionaryWithValuesForKeys:[[liveActivitySyncStatePerActivityId keysOfEntriesPassingTest:^BOOL(id  _Nonnull activityId, id  _Nonnull savedState, BOOL * _Nonnull stop) {
        return ![WPJsonSyncLiveActivity destroyedFromSavedState:savedState];
    }] allObjects]];
    @synchronized (self) {
        [self _setNSDictionaryAsJSON:liveActivitySyncStatePerActivityId forKey:USER_DEFAULTS_LIVE_ACTIVITY_SYNC_STATE_PER_ACTIVITY_ID_KEY];
    }
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *) liveActivitySyncActivityIdsPerAttributesTypeName {
    NSMutableDictionary<NSString *, NSArray *> *rtn = [NSMutableDictionary new];
    for (NSDictionary *savedState in [[self liveActivitySyncStatePerActivityId] allValues]) {
        NSString *activityId = [WPJsonSyncLiveActivity activityIdFromSavedState:savedState];
        NSString *attributesTypeName = [WPJsonSyncLiveActivity attributesTypeNameFromSavedState:savedState];
        if (activityId == nil || attributesTypeName == nil) {
            continue;
        }
        NSMutableArray *rtnForType = (NSMutableArray *) [WPNSUtil arrayForKey:attributesTypeName inDictionary:rtn];
        if (rtnForType == nil) {
            rtnForType = [NSMutableArray new];
            rtn[attributesTypeName] = rtnForType;
        }
        [rtnForType addObject:activityId];
    };
    return rtn;
}

@end
