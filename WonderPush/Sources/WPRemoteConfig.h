//
//  WPRemoteConfig.h
//  WonderPush
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define WP_REMOTE_CONFIG_DEFAULT_MINIMUM_CONFIG_AGE 86400
#define WP_REMOTE_CONFIG_DEFAULT_MAXIMUM_CONFIG_AGE 86400 * 10

extern NSString * const WPRemoteConfigUpdatedNotification;

@interface WPRemoteConfig : NSObject<NSCoding, NSSecureCoding>
@property (nonatomic, nonnull, readonly) NSDictionary *data;
@property (nonatomic, nonnull, readonly) NSString *version;
@property (nonatomic, nonnull, readonly) NSDate *fetchDate;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate;
- (BOOL) hasHigherVersionThan:(WPRemoteConfig *)other;
+ (NSComparisonResult) compareVersion:(NSString *)version1 withVersion: (NSString *)version2;
@end

@protocol WPRemoteConfigFetcher
- (void) fetchConfigWithVersion: (NSString * _Nullable)version
                     completion: (void(^)(WPRemoteConfig * _Nullable,  NSError * _Nullable))completion;
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

@interface WPRemoteConfigStorateWithUserDefaults : NSObject<WPRemoteConfigStorage>
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
- (void) read: (void(^)(WPRemoteConfig * _Nullable,  NSError * _Nullable)) completion;
@end

NS_ASSUME_NONNULL_END