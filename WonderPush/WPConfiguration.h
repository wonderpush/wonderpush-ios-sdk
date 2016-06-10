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

#import <Foundation/Foundation.h>

#define USER_DEFAULTS_CLIENT_ID_KEY @"__wonderpush_client_id"
#define USER_DEFAULTS_QUEUED_NOTIFICATIONS @"__wonderpush_queued_notifications"
#define USER_DEFAULTS_EVENT_RECEIVED_HISTORY @"__wonderpush_event_received_history"
#define USER_DEFAULTS_DEVICE_TOKEN_KEY @"__wonderpush_device_token"
#define USER_DEFAULTS_DEVICE_TOKEN_ASSOCIATED_TO_USER_ID_KEY @"__wonderpush_device_token_associated_to_user_id"

#define USER_DEFAULTS_PER_USER_ARCHIVE_KEY @"__wonderpush_per_user_archive"
#define USER_DEFAULTS_ACCESS_TOKEN_KEY @"__wonderpush_access_token"
#define USER_DEFAULTS_ACCESS_TOKEN_IS_ANONYMOUS_KEY @"__wonderpush_access_token_is_anonymous"
#define USER_DEFAULTS_USER_ID_KEY @"__wonderpush_userid"
#define USER_DEFAULTS_INSTALLATION_ID @"_wonderpush_installationId"
#define USER_DEFAULTS_SID_KEY @"__wonderpush_sid"
#define USER_DEFAULTS_NOTIFICATION_ENABLED_KEY @"__wonderpush_notification_enabled"
#define USER_DEFAULTS_CACHED_INSTALLATION_CORE_PROPERTIES @"_wonderpush_cachedInstallationCoreProperties"
#define USER_DEFAULTS_CACHED_INSTALLATION_CORE_PROPERTIES_DATE @"_wonderpush_cachedInstallationCorePropertiesDate"
#define USER_DEFAULTS_CACHED_DEVICE_TOKEN_DATE @"_wonderpush_cachedDeviceTokenDate"
#define USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN @"_wonderpush_cachedInstallationCustomPropertiesWritten"
#define USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_WRITTEN_DATE @"_wonderpush_cachedInstallationCustomPropertiesWrittenDate"
#define USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED @"_wonderpush_cachedInstallationCustomPropertiesUpdated"
#define USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_UPDATED_DATE @"_wonderpush_cachedInstallationCustomPropertiesUpdatedDate"
#define USER_DEFAULTS_CACHED_INSTALLATION_CUSTOM_PROPERTIES_FIRST_DELAYED_WRITE_DATE @"_wonderpush_cachedInstallationCustomPropertiesFirstDelayedWriteDate"
#define USER_DEFAULTS_LAST_RECEIVED_NOTIFICATION @"_wonderpush_lastReceivedNotification"
#define USER_DEFAULTS_LAST_RECEIVED_NOTIFICATION_DATE @"_wonderpush_lastReceivedNotificationDate"
#define USER_DEFAULTS_LAST_OPENED_NOTIFICATION @"_wonderpush_lastOpenedNotification"
#define USER_DEFAULTS_LAST_OPENED_NOTIFICATION_DATE @"_wonderpush_lastOpenedNotificationDate"
#define USER_DEFAULTS_LAST_INTERACTION_DATE @"_wonderpush_lastInteractionDate"
#define USER_DEFAULTS_LAST_APP_OPEN_INFO @"_wonderpush_lastAppOpenInfo"
#define USER_DEFAULTS_LAST_APP_OPEN_DATE @"_wonderpush_lastAppOpenDate"
#define USER_DEFAULTS_LAST_APP_CLOSE_DATE @"_wonderpush_lastAppCloseDate"


/**
 WPConfiguration is a singleton that holds configuration values for this WonderPush installation
 */

@interface WPConfiguration : NSObject

+ (WPConfiguration *)sharedConfiguration;

@property (strong, nonatomic) NSString *clientId;

@property (strong, nonatomic) NSString *clientSecret;

@property (readonly, nonatomic) NSURL *baseURL;

@property (assign, nonatomic) NSTimeInterval timeOffset;

@property (assign, nonatomic) NSTimeInterval timeOffsetPrecision;

@property (readonly) BOOL usesSandbox;

/// The access token used to hit the WonderPush API
@property (readonly) NSString *accessToken;

// The device token used for APNS
@property (readonly) NSString *deviceToken;
@property (readonly) NSString *deviceTokenAssociatedToUserId;
@property (nonatomic, strong) NSDate *cachedDeviceTokenDate;

/// The sid used to hit the WonderPush API
@property (nonatomic, strong) NSString *sid;

@property (nonatomic, strong) NSString *userId;

@property (nonatomic, strong) NSString *installationId;

@property (nonatomic) BOOL notificationEnabled;

@property (nonatomic, strong) NSDictionary *cachedInstallationCoreProperties;
@property (nonatomic, strong) NSDate *cachedInstallationCorePropertiesDate;

@property (nonatomic, strong) NSDictionary *cachedInstallationCustomPropertiesWritten;
@property (nonatomic, strong) NSDate *cachedInstallationCustomPropertiesWrittenDate;
@property (nonatomic, strong) NSDictionary *cachedInstallationCustomPropertiesUpdated;
@property (nonatomic, strong) NSDate *cachedInstallationCustomPropertiesUpdatedDate;
@property (nonatomic, strong) NSDate *cachedInstallationCustomPropertiesFirstDelayedWriteDate;

@property (nonatomic, strong) NSDictionary *lastReceivedNotification;
@property (nonatomic, strong) NSDate *lastReceivedNotificationDate;
@property (nonatomic, strong) NSDictionary *justOpenedNotification; // kept in memory only
@property (nonatomic, strong) NSDictionary *lastOpenedNotification;
@property (nonatomic, strong) NSDate *lastOpenedNotificationDate;
@property (nonatomic, strong) NSDate *lastInteractionDate;
@property (nonatomic, strong) NSDictionary *lastAppOpenInfo;
@property (nonatomic, strong) NSDate *lastAppOpenDate;
@property (nonatomic, strong) NSDate *lastAppCloseDate;

- (void) changeUserId:(NSString *)newUserId;

- (void) setAccessToken:(NSString *)accessToken;

- (void) setDeviceToken:(NSString *)deviceToken;
- (void) setDeviceTokenAssociatedToUserId:(NSString *)userId;

-(void) setStoredClientId:(NSString *)clientId;

-(NSString *) getStoredClientId;

-(void) addToQueuedNotifications:(NSDictionary *) notification;

-(NSMutableArray *) getQueuedNotifications;

-(void) clearQueuedNotifications;

- (NSString *) getAccessTokenForUserId:(NSString *)userId;

@end
