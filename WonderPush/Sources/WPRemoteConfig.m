//
//  WPRemoteConfig.m
//  WonderPush
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPRemoteConfig.h"

NSString * const WPRemoteConfigUpdatedNotification = @"WPRemoteConfigUpdatedNotification";

#pragma mark - Data

@implementation WPRemoteConfig
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version {
    return [self initWithData:data version:version fetchDate:[NSDate date]];
}
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate {
    if (self = [super init]) {
        _data = data;
        _version = version;
        _fetchDate = fetchDate;
    }
    return self;
}
@end

#pragma mark - Fetcher

@implementation WPRemoteConfigFetcherWithURLSession

- (instancetype) initWithClientId:(NSString *)clientId {
    if (self = [super init]) {
        _clientId = clientId;
    }
    return self;
}

- (void) fetchConfigWithVersion:(NSString *)version completion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    
}

@end

#pragma mark - Storage

@implementation WPRemoteConfigStorateWithUserDefaults

- (void) storeRemoteConfig:(WPRemoteConfig *)remoteConfig
                completion:(void (^)(NSError * _Nullable))completion {
    
}

- (void) loadRemoteConfigWithCompletion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    
}

@end

#pragma mark - Manager

@implementation WPRemoteConfigManager

- (instancetype) initWithRemoteConfigFetcher:(id<WPRemoteConfigFetcher>)remoteConfigFetcher
                                     storage:(nonnull id<WPRemoteConfigStorage>)remoteConfigStorage {
    if (self = [super init]) {
        _remoteConfigFetcher = remoteConfigFetcher;
        _remoteConfigStorage = remoteConfigStorage;
        _minimumFetchInterval = WP_REMOTE_CONFIG_DEFAULT_MINIMUM_FETCH_INTERVAL;
        _maximumFetchInterval = WP_REMOTE_CONFIG_DEFAULT_MAXIMUM_FETCH_INTERVAL;
    }
    return self;
}

- (void) declareVersion:(NSString *)version {
    
}

- (void) read:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    
}

@end
