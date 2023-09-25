//
//  WPRemoteConfig.m
//  WonderPush
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPRemoteConfig.h"
#import "WPSemver.h"
#import <WonderPushCommon/WPLog.h>
#import "WonderPush_private.h"
#import <WonderPushCommon/WPErrors.h>
#import <WonderPushCommon/WPNSUtil.h>

NSString * const WPRemoteConfigUpdatedNotification = @"WPRemoteConfigUpdatedNotification";

#pragma mark - Data

@interface WPRemoteConfig ()
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate maxAge:(NSTimeInterval)maxAge;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate maxAge:(NSTimeInterval)maxAge minAge:(NSTimeInterval)minAge;
@end

@implementation WPRemoteConfig

+ (instancetype)withJSON:(id)JSON error:(NSError *__autoreleasing  _Nullable * _Nullable)error {
    NSDictionary *configurationDict = JSON;
    if (![configurationDict isKindOfClass:NSDictionary.class]) return nil;
    
    // Get the version
    id version = configurationDict[@"version"];

    // Version can be a number, turn into a string
    if ([version isKindOfClass:NSNumber.class]) version = [version stringValue];

    if (![version isKindOfClass:NSString.class]) {
        if (error != nil) {
            *error = [NSError errorWithDomain:WPErrorDomain code:WPErrorInvalidFormat userInfo:nil];
        }
        return nil;
    }

    NSNumber *maxAgeNumber = [WPNSUtil numberForKey:@"maxAge" inDictionary:configurationDict]; // milliseconds
    if (maxAgeNumber == nil) {
        maxAgeNumber = [WPNSUtil numberForKey:@"cacheTtl" inDictionary:configurationDict]; // fallback on cacheTtl
    }
    NSTimeInterval maxAge = maxAgeNumber != nil ? maxAgeNumber.doubleValue / 1000 : 0;
    NSNumber *minAgeNumber = [WPNSUtil numberForKey:@"minAge" inDictionary:configurationDict]; // milliseconds
    if (minAgeNumber == nil) {
        minAgeNumber = [WPNSUtil numberForKey:@"cacheMinAge" inDictionary:configurationDict];
    }
    NSTimeInterval minAge = minAgeNumber != nil ? minAgeNumber.doubleValue / 1000 : 0;
    return [[WPRemoteConfig alloc] initWithData:configurationDict version:version fetchDate:[NSDate date] maxAge:maxAge minAge:minAge];
}

- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version {
    return [self initWithData:data version:version fetchDate:[NSDate date]];
}

- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate {
    return [self initWithData:data version:version fetchDate:fetchDate maxAge:0];
}

- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate maxAge:(NSTimeInterval)maxAge {
    return [self initWithData:data version:version fetchDate:fetchDate maxAge:maxAge minAge:0];
}

- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate maxAge:(NSTimeInterval)maxAge minAge:(NSTimeInterval)minAge {
    if (self = [super init]) {
        _data = data;
        _version = version;
        _fetchDate = fetchDate;
        _maxAge = maxAge;
        _minAge = minAge;
    }
    return self;
}

- (BOOL) hasHigherVersionThan:(WPRemoteConfig *)other {
    return [[self class] compareVersion:self.version withVersion:other.version] == NSOrderedDescending;
}

+ (NSComparisonResult) compareVersion:(NSString *)version1 withVersion:(NSString *)version2 {
    WPSemver *semver1 = [WPSemver semverWithString:version1];
    WPSemver *semver2 = [WPSemver semverWithString:version2];
    
    if (![semver1 isValid] && [semver2 isValid]) return NSOrderedAscending;
    if (![semver2 isValid] && [semver1 isValid]) return NSOrderedDescending;
    if (![semver1 isValid] && ![semver2 isValid]) return NSOrderedSame;
    
    return [semver1 compare:semver2];
}

- (NSString *) description {
    NSString *dataString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self.data options:0 error:nil] encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"<WPRemoteConfig version=%@ fetchDate=%@ data=%@>", self.version, self.fetchDate, dataString];
}

- (instancetype) initWithCoder:(NSCoder *)coder {
    NSString *version = [coder decodeObjectOfClass:NSString.class forKey:@"version"];
    NSDate *fetchDate = [coder decodeObjectOfClass:NSDate.class forKey:@"fetchDate"];
    NSSet *classes = [NSSet setWithObjects:NSString.class, NSNull.class, NSDate.class, NSArray.class, NSDictionary.class, NSNumber.class, nil];
    NSDictionary *data = [coder decodeObjectOfClasses:classes forKey:@"data"];
    NSTimeInterval maxAge = [coder decodeDoubleForKey:@"maxAge"];
    NSTimeInterval minAge = [coder decodeDoubleForKey:@"minAge"];
    return [self initWithData:data version:version fetchDate:fetchDate maxAge:maxAge minAge:minAge];
}

- (void) encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.fetchDate forKey:@"fetchDate"];
    [coder encodeObject:self.data forKey:@"data"];
    [coder encodeDouble:self.maxAge forKey:@"maxAge"];
    [coder encodeDouble:self.minAge forKey:@"minAge"];
}

- (BOOL) isExpired {
    return self.maxAge > 0 && [self.fetchDate timeIntervalSinceNow] < -self.maxAge;
}

- (BOOL)hasReachedMinAge {
    return [self.fetchDate timeIntervalSinceNow] <= -self.minAge;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}
@end

#pragma mark - Fetcher

@interface WPRemoteConfigFetcherWithURLSession ()
@property (nonnull, nonatomic, strong) NSURLSession *session;
@end

@implementation WPRemoteConfigFetcherWithURLSession

- (instancetype) initWithClientId:(NSString *)clientId {
    if (self = [super init]) {
        _clientId = clientId;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (void) fetchConfigWithVersion:(NSString *)version completion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@?_=%f", REMOTE_CONFIG_BASE_URL, self.clientId, REMOTE_CONFIG_SUFFIX, [NSDate date].timeIntervalSince1970]];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:10];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
            if (HTTPResponse.statusCode != 200) {
                completion(nil, [NSError errorWithDomain:WPErrorDomain code:WPErrorNotFound userInfo:@{
                    @"response": HTTPResponse,
                }]);
                return;
            }
        }
        NSError *JSONError = nil;
        id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
        if (JSONError) {
            completion(nil, JSONError);
            return;
        }
        NSDictionary *configurationDict = [JSONObject isKindOfClass:NSDictionary.class] ? JSONObject : [NSDictionary new];

        NSError *fromJSONError = nil;
        WPRemoteConfig *remoteConfig = [WPRemoteConfig withJSON:configurationDict error:&fromJSONError];
        completion(remoteConfig, fromJSONError);

    }];
    [task resume];
}

@end

#pragma mark - Storage

@implementation WPRemoteConfigStorageWithUserDefaults

- (instancetype) initWithClientId:(NSString *)clientId {
    if (self = [super init]) {
        _clientId = clientId;
    }
    return self;
}

- (void) storeRemoteConfig:(WPRemoteConfig *)remoteConfig
                completion:(void (^)(NSError * _Nullable))completion {
    NSError *error = nil;
    NSData *data = nil;
    if (@available(iOS 11.0, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:remoteConfig requiringSecureCoding:YES error:&error];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        data = [NSKeyedArchiver archivedDataWithRootObject:remoteConfig];
#pragma clang diagnostic pop
    }
    if (error) {
        completion(error);
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:data forKey:[self.class remoteConfigKeyWithClientId:self.clientId]];
    [defaults synchronize];
    completion(nil);
}

- (void) loadRemoteConfigAndHighestDeclaredVersionWithCompletion:(void (^)(WPRemoteConfig * _Nullable, NSString * _Nullable, NSError * _Nullable))completion {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Get remote config
    NSData *data = [defaults objectForKey:[self.class remoteConfigKeyWithClientId:self.clientId]];
    NSError *error = nil;
    WPRemoteConfig *config = nil;
    if (data) {
        NSError *error = nil;
        if (@available(iOS 11.0, *)) {
            config = [NSKeyedUnarchiver unarchivedObjectOfClass:WPRemoteConfig.class fromData:data error:&error];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            config = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
        }
    }
    
    // Get highest version
    NSArray *versions = [defaults objectForKey:[self.class versionsKeyWithClientId:self.clientId]];
    NSString *highestVersion = nil;
    if (versions) {
        for (NSString *version in versions) {
            if (!highestVersion) {
                highestVersion = version;
                continue;
            }
            if ([WPRemoteConfig compareVersion:highestVersion withVersion:version] == NSOrderedAscending) {
                highestVersion = version;
            }
        }
    }
    completion(config, highestVersion, error);
}

- (void)declareVersion:(nonnull NSString *)version completion:(nonnull void (^)(NSError * _Nullable))completion {
    NSString *key = [self.class versionsKeyWithClientId:self.clientId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *versions = [defaults objectForKey:key];
    NSMutableArray *mutableVersions = versions ? versions.mutableCopy : [NSMutableArray new];
    [mutableVersions addObject:version];
    // Dedup with NSSet
    [defaults setObject:[NSSet setWithArray:mutableVersions].allObjects forKey:key];
    [defaults synchronize];
    completion(nil);
}

+ (NSString *) remoteConfigKeyWithClientId:(NSString *)clientId {
    return [NSString stringWithFormat:@"WP_REMOTE_CONFIG_%@", clientId];
}

+ (NSString *) versionsKeyWithClientId:(NSString *)clientId {
    return [NSString stringWithFormat:@"WP_REMOTE_CONFIG_VERSIONS_%@", clientId];
}

@end

#pragma mark - Manager

@interface WPRemoteConfigManager ()
@property (atomic) BOOL isFetching;
@property (nonatomic, strong) NSMutableArray<WPRemoteConfigReadCompletionHandler> *queuedHandlers;
@property (atomic, nullable, strong) NSDate *lastFetchDate;
@property (atomic, nullable, strong) WPRemoteConfig *storedConfig;
@property (atomic, nullable, strong) NSString *storedHighestVersion;
- (void) readConfigAndHighestDeclaredVersionFromStorageWithCompletion:(void(^)(WPRemoteConfig * _Nullable, NSString * _Nullable, NSError * _Nullable))completion;
- (void) fetchAndStoreConfigWithVersion:(NSString * _Nullable)version currentConfig:(WPRemoteConfig * _Nullable)currentConfig completion: (WPRemoteConfigReadCompletionHandler) completion;
@end

@implementation WPRemoteConfigManager

- (instancetype) initWithRemoteConfigFetcher:(id<WPRemoteConfigFetcher>)remoteConfigFetcher
                                     storage:(nonnull id<WPRemoteConfigStorage>)remoteConfigStorage {
    if (self = [super init]) {
        _remoteConfigFetcher = remoteConfigFetcher;
        _remoteConfigStorage = remoteConfigStorage;
        _minimumConfigAge = WP_REMOTE_CONFIG_DEFAULT_MINIMUM_CONFIG_AGE;
        _maximumConfigAge = WP_REMOTE_CONFIG_DEFAULT_MAXIMUM_CONFIG_AGE;
        _minimumFetchInterval = WP_REMOTE_CONFIG_DEFAULT_MINIMUM_FETCH_INTERVAL;
        _queuedHandlers = [NSMutableArray new];
    }
    return self;
}

- (void) declareVersion:(NSString *)version {
    [self.remoteConfigStorage declareVersion:version completion:^(NSError *declareVersionError) {
        if (declareVersionError) {
            WPLog(@"Error declaring version to storage: %@", declareVersionError.description);
        } else {
            if (!self.storedHighestVersion || [WPRemoteConfig compareVersion:self.storedHighestVersion withVersion:version] == NSOrderedAscending) {
                self.storedHighestVersion = version;
            }
        }
        [self readConfigAndHighestDeclaredVersionFromStorageWithCompletion:^(WPRemoteConfig *config, NSString *highestVersion, NSError *error) {
            if (error) {
                WPLog(@"Could not get RemoteConfig from storage: %@", error.description);
                return;
            }
            
            if (config) {
                NSTimeInterval configAge = -[config.fetchDate timeIntervalSinceNow];

                // Do not fetch too often
                if (configAge < self.minimumConfigAge || !config.hasReachedMinAge) return;

                // If we're declaring the same version as the current config, update the current config's fetchDate
                if ([WPRemoteConfig compareVersion:config.version withVersion:version] == NSOrderedSame) {
                    WPRemoteConfig *configWithUpdatedDate = [[WPRemoteConfig alloc] initWithData:config.data version:config.version fetchDate:[NSDate date] maxAge:config.maxAge minAge:config.minAge];
                    [self.remoteConfigStorage storeRemoteConfig:configWithUpdatedDate completion:^(NSError *error) {
                        if (!error) self.storedConfig = configWithUpdatedDate;
                    }];
                    return;
                }

                // Only fetch a higher version
                if ([WPRemoteConfig compareVersion:config.version withVersion:highestVersion] != NSOrderedAscending) return;
            }
            
            NSTimeInterval lastFetchInterval = -[self.lastFetchDate timeIntervalSinceNow];
            // Do not update too frequently
            if (self.lastFetchDate && lastFetchInterval < self.minimumFetchInterval) return;
            [self fetchAndStoreConfigWithVersion:highestVersion currentConfig:config completion:nil];

        }];
    }];

}

- (void) read:(WPRemoteConfigReadCompletionHandler)completion {
    @synchronized (self) {
        if (self.isFetching) {
            [self.queuedHandlers addObject:completion];
            return;
        }
    }

    [self readConfigAndHighestDeclaredVersionFromStorageWithCompletion:^(WPRemoteConfig *storedConfig, NSString *highestVersion, NSError *storageError) {
        if (storageError) {
            completion(nil, storageError);
            return;
        }
        NSTimeInterval lastFetchInterval = -[self.lastFetchDate timeIntervalSinceNow];

        if (!storedConfig) {
            // Do not update too frequently
            if (self.lastFetchDate && lastFetchInterval < self.minimumFetchInterval) {
                completion(nil, nil);
                return;
            };

            [self fetchAndStoreConfigWithVersion:nil currentConfig:storedConfig completion:^(WPRemoteConfig *config, NSError *fetchError) {
                if (fetchError) {
                    completion(nil, fetchError);
                    return;
                }
                completion(config, nil);
            }];
            return;
        }
        BOOL higherVersionExists = NSOrderedAscending == [WPRemoteConfig compareVersion:storedConfig.version withVersion:highestVersion];
        BOOL shouldFetch = higherVersionExists;
        NSString *versionToFetch = highestVersion;
        
        // Do not fetch too often
        NSTimeInterval configAge = -[storedConfig.fetchDate timeIntervalSinceNow];
        if (shouldFetch && (configAge < self.minimumConfigAge || configAge < storedConfig.minAge)) {
            shouldFetch = NO;
        }
        
        // Force fetch if expired
        BOOL isExpired = configAge > self.maximumConfigAge
            || storedConfig.isExpired;
        if (!shouldFetch && isExpired) {
            shouldFetch = YES;
            if (!higherVersionExists) versionToFetch = storedConfig.version;
        }

        // Do not fetch too often
        if (shouldFetch && self.lastFetchDate && lastFetchInterval < self.minimumFetchInterval) {
            shouldFetch = NO;
        }

        if (!shouldFetch) {
            completion(storedConfig, nil);
            return;
        }
        
        [self fetchAndStoreConfigWithVersion:versionToFetch currentConfig:storedConfig completion:^(WPRemoteConfig *configFetchedAndStored, NSError *error) {
            completion(configFetchedAndStored ?: storedConfig, error);
        }];
    }];    
}

- (void) readConfigAndHighestDeclaredVersionFromStorageWithCompletion:(void (^)(WPRemoteConfig * _Nullable, NSString * _Nullable, NSError * _Nullable))completion {

    if (self.storedConfig && self.storedHighestVersion) {
        completion(self.storedConfig, self.storedHighestVersion, nil);
    } else {
        [self.remoteConfigStorage loadRemoteConfigAndHighestDeclaredVersionWithCompletion:^(WPRemoteConfig *config, NSString *highestVersion, NSError *error) {
            if (config && !error) self.storedConfig = config;
            if (highestVersion && !error) self.storedHighestVersion = highestVersion;
            completion(config, highestVersion, error);
        }];
    }
}

- (void) fetchAndStoreConfigWithVersion:(NSString * _Nullable)version currentConfig:(WPRemoteConfig * _Nullable)currentConfig completion:(WPRemoteConfigReadCompletionHandler _Nullable)completion {

    // Is fetch disabled?
    if (currentConfig && [[WPNSUtil numberForKey:WP_REMOTE_CONFIG_DISABLE_FETCH_KEY inDictionary:currentConfig.data] boolValue]) {
        if (completion) completion(currentConfig, nil);
        return;
    }

    @synchronized (self) {
        if (self.isFetching) {
            if (completion) {
                [self.queuedHandlers addObject:completion];
            }
            return;
        }
        self.isFetching = YES;
    }

    self.lastFetchDate = [NSDate date];
    [self.remoteConfigFetcher fetchConfigWithVersion:version completion:^(WPRemoteConfig *newConfig, NSError *fetchError) {
        WPRemoteConfigReadCompletionHandler handler = ^(WPRemoteConfig *config, NSError *error) {
            NSArray *queuedHandlersCopy;
            @synchronized (self) {
                self.isFetching = NO;
                queuedHandlersCopy = [NSArray arrayWithArray:self.queuedHandlers];
                [self.queuedHandlers removeAllObjects];
            }
            for (WPRemoteConfigReadCompletionHandler queuedHandler in queuedHandlersCopy) {
                // Avoid deadlocks on self.queuedHandlers
                // The handler might himself read the config and wait for this @synchronized block to finish
                dispatch_async(dispatch_get_main_queue(), ^{
                    queuedHandler(config, error);
                });
            }

            if (completion) completion(config, error);
        };
        if (newConfig && !fetchError) {
            if (currentConfig && [currentConfig hasHigherVersionThan:newConfig]) {
                handler(currentConfig, nil);
                return;
            }
            [self.remoteConfigStorage storeRemoteConfig:newConfig completion:^(NSError *storageError) {
                if (storageError) {
                    WPLog(@"Could not store RemoteConfig in storage: %@", storageError.description);
                    handler(nil, storageError);
                } else {
                    self.storedConfig = newConfig;
                    [self.remoteConfigStorage declareVersion:newConfig.version completion:^(NSError *declareVersionError) {
                        if (declareVersionError) {
                            WPLog(@"Error declaring version to storage: %@", declareVersionError.description);
                        }
                        if (!currentConfig || [newConfig hasHigherVersionThan:currentConfig]) {
                            WPLogDebug(@"Got new configuration with version %@", newConfig.version);
                            [[NSNotificationCenter defaultCenter] postNotificationName:WPRemoteConfigUpdatedNotification object:newConfig];
                        }
                        handler(newConfig, nil);
                    }];
                }
            }];
            return;
        }
        if (fetchError) {
            WPLog(@"Could not fetch RemoteConfig from server: %@", fetchError.description);
        }
        handler(currentConfig, fetchError);
    }];
}

@end
