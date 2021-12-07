//
//  WPRemoteConfig.h
//  WonderPush
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define WP_REMOTE_CONFIG_DEFAULT_MINIMUM_CONFIG_AGE 0
#define WP_REMOTE_CONFIG_DEFAULT_MINIMUM_FETCH_INTERVAL 5
#define WP_REMOTE_CONFIG_DEFAULT_MAXIMUM_CONFIG_AGE 86400 * 10
#define WP_REMOTE_CONFIG_DISABLE_FETCH_KEY @"disableConfigFetch"
#define WP_REMOTE_CONFIG_DISABLE_JSON_SYNC_KEY @"disableJsonSync"
#define WP_REMOTE_CONFIG_DISABLE_API_CLIENT_KEY @"disableApiClient"
#define WP_REMOTE_CONFIG_DISABLE_MEASUREMENTS_API_CLIENT_KEY @"disableMeasurementsApiClient"
#define WP_REMOTE_CONFIG_EVENTS_BLACK_WHITE_LIST_KEY @"eventsBlackWhiteList"
#define WP_REMOTE_CONFIG_TRACK_EVENTS_FOR_NON_SUBSCRIBERS @"trackEventsForNonSubscribers"
#define WP_REMOTE_CONFIG_ALLOW_ACCESS_TOKEN_FOR_NON_SUBSCRIBERS @"allowAccessTokenForNonSubscribers"
#define WP_REMOTE_CONFIG_DO_NOT_SEND_PRESENCE_ON_APPLICATION_WILL_RESIGN_ACTIVE @"doNotSendPresenceOnApplicationWillResignActive"
extern NSString * const WPRemoteConfigUpdatedNotification;

@interface WPRemoteConfig : NSObject<NSCoding, NSSecureCoding>
@property (nonatomic, nonnull, readonly) NSDictionary *data;
@property (nonatomic, nonnull, readonly) NSString *version;
@property (nonatomic, nonnull, readonly) NSDate *fetchDate;
/**
 Maximum time since fetchDate before isExpired becomes true. Set to 0 to never expire.
 */
@property (nonatomic, readonly) NSTimeInterval maxAge;
@property (nonatomic, readonly) NSTimeInterval minAge;
+ (instancetype _Nullable) withJSON:(id)JSON error:(NSError **)error;
- (BOOL) hasHigherVersionThan:(WPRemoteConfig *)other;
- (BOOL) isExpired;
- (BOOL) hasReachedMinAge;
+ (NSComparisonResult) compareVersion:(NSString *)version1 withVersion: (NSString *)version2;
@end

typedef void(^WPRemoteConfigReadCompletionHandler)(WPRemoteConfig * _Nullable, NSError * _Nullable);

@protocol WPRemoteConfigFetcher
- (void) fetchConfigWithVersion: (NSString * _Nullable)version
                     completion: (WPRemoteConfigReadCompletionHandler)completion;
@end

@protocol WPRemoteConfigStorage
- (void) storeRemoteConfig:(WPRemoteConfig *)remoteConfig
                completion:(void(^)(NSError * _Nullable)) completion;
- (void) loadRemoteConfigAndHighestDeclaredVersionWithCompletion:(void(^)(WPRemoteConfig * _Nullable, NSString * _Nullable, NSError * _Nullable)) completion;
- (void) declareVersion:(NSString *)version completion:(void(^)(NSError * _Nullable)) completion;
@end

@interface WPRemoteConfigFetcherWithURLSession : NSObject<WPRemoteConfigFetcher>
@property (nonatomic, nonnull, readonly) NSString * clientId;
- (instancetype) initWithClientId:(NSString *)clientId;
@end

@interface WPRemoteConfigStorageWithUserDefaults : NSObject<WPRemoteConfigStorage>
@property (nonatomic, nonnull, readonly) NSString *clientId;
- (instancetype) initWithClientId:(NSString *)clientId;
+ (NSString *) remoteConfigKeyWithClientId:(NSString *)clientId;
+ (NSString *) versionsKeyWithClientId:(NSString *)clientId;
@end

@interface WPRemoteConfigManager : NSObject
@property (nonatomic, nonnull, strong) id<WPRemoteConfigFetcher> remoteConfigFetcher;
@property (nonatomic, nonnull, strong) id<WPRemoteConfigStorage> remoteConfigStorage;
@property (nonatomic, assign) NSTimeInterval minimumFetchInterval;
@property (nonatomic, assign) NSTimeInterval minimumConfigAge;
@property (nonatomic, assign) NSTimeInterval maximumConfigAge;
- (instancetype) initWithRemoteConfigFetcher:(id<WPRemoteConfigFetcher>)remoteConfigFetcher
                                     storage:(id<WPRemoteConfigStorage>)remoteConfigStorage;
- (void) declareVersion:(NSString *)version;
- (void) read: (WPRemoteConfigReadCompletionHandler) completion;
@end

NS_ASSUME_NONNULL_END
