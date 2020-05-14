//
//  WPRemoteConfig.m
//  WonderPush
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPRemoteConfig.h"
#import "WPSemver.h"
#import "WPLog.h"
#import "WonderPush_private.h"
#import "WPUtil.h"

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
    return [self initWithData:data version:version fetchDate:fetchDate];
}

- (void) encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.fetchDate forKey:@"fetchDate"];
    [coder encodeObject:self.data forKey:@"data"];
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
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", REMOTE_CONFIG_BASE_URL, self.clientId]];
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
            completion(nil, error);
            return;
        }
        NSDictionary *configurationDict = [JSONObject isKindOfClass:NSDictionary.class] ? JSONObject : [NSDictionary new];
        NSString *version = [configurationDict objectForKey:@"_configVersion"];
        if ([version isKindOfClass:NSString.class]) {
            WPRemoteConfig *remoteConfig = [[WPRemoteConfig alloc] initWithData:configurationDict version:version];
            completion(remoteConfig, nil);
            return;
        }
        completion(nil, [NSError errorWithDomain:WPErrorDomain code:WPErrorInvalidFormat userInfo:nil]);
    }];
    [task resume];
}

@end

#pragma mark - Storage

@implementation WPRemoteConfigStorateWithUserDefaults

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
        data = [NSKeyedArchiver archivedDataWithRootObject:remoteConfig];
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
            config = [NSKeyedUnarchiver unarchiveObjectWithData:data];
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
@property (nonatomic, nullable, strong) NSDate *lastFetchDate;
@property (nonatomic, nullable, strong) WPRemoteConfig *storedConfig;
@property (nonatomic, nullable, strong) NSString *storedHighestVersion;
- (void) readConfigAndHighestDeclaredVersionFromStorageWithCompletion:(void(^)(WPRemoteConfig * _Nullable, NSString * _Nullable, NSError * _Nullable))completion;
- (void) storeConfig:(WPRemoteConfig *)config completion:(void(^)(NSError * _Nullable))completion;
- (void) fetchAndStoreConfigWithVersion:(NSString * _Nullable)version currentConfig:(WPRemoteConfig * _Nullable)currentConfig completion: (void(^ _Nullable)(WPRemoteConfig * _Nullable, NSError * _Nullable)) completion;
@end

@implementation WPRemoteConfigManager

- (instancetype) initWithRemoteConfigFetcher:(id<WPRemoteConfigFetcher>)remoteConfigFetcher
                                     storage:(nonnull id<WPRemoteConfigStorage>)remoteConfigStorage {
    if (self = [super init]) {
        _remoteConfigFetcher = remoteConfigFetcher;
        _remoteConfigStorage = remoteConfigStorage;
        _minimumConfigAge = WP_REMOTE_CONFIG_DEFAULT_MINIMUM_CONFIG_AGE;
        _maximumConfigAge = WP_REMOTE_CONFIG_DEFAULT_MAXIMUM_CONFIG_AGE;
        _minimumFetchInterval = WP_REMOTE_CONFIG_DEFAULT_MINIMUM_CONFIG_AGE;
    }
    return self;
}

- (void) declareVersion:(NSString *)version {
    if (!self.storedHighestVersion || [WPRemoteConfig compareVersion:self.storedHighestVersion withVersion:version] == NSOrderedAscending) {
        self.storedHighestVersion = version;
    }
    [self.remoteConfigStorage declareVersion:version completion:^(NSError *declareVersionError) {
        if (declareVersionError) {
            WPLog(@"Error declaring version to storage: %@", declareVersionError.description);
        }
        [self readConfigAndHighestDeclaredVersionFromStorageWithCompletion:^(WPRemoteConfig *config, NSString *highestVersion, NSError *error) {
            if (error) {
                WPLog(@"Could not get RemoteConfig from storage: %@", error.description);
                return;
            }
            
            if (config) {
                NSTimeInterval configAge = -[config.fetchDate timeIntervalSinceNow];

                // Do not fetch too often
                if (configAge < self.minimumConfigAge) return;

                // Only fetch a higher version
                if ([WPRemoteConfig compareVersion:config.version withVersion:version] != NSOrderedAscending) return;
            }
            
            NSTimeInterval lastFetchInterval = -[self.lastFetchDate timeIntervalSinceNow];
            // Do not update too frequently
            if (self.lastFetchDate && lastFetchInterval < self.minimumFetchInterval) return;
            [self fetchAndStoreConfigWithVersion:version currentConfig:config completion:nil];

        }];
    }];

}

- (void) read:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    [self readConfigAndHighestDeclaredVersionFromStorageWithCompletion:^(WPRemoteConfig *config, NSString *highestVersion, NSError *storageError) {
        if (storageError) {
            completion(nil, storageError);
            return;
        }
        NSTimeInterval lastFetchInterval = -[self.lastFetchDate timeIntervalSinceNow];

        if (!config) {
            // Do not update too frequently
            if (self.lastFetchDate && lastFetchInterval < self.minimumFetchInterval) {
                completion(nil, nil);
                return;
            };

            [self fetchAndStoreConfigWithVersion:nil currentConfig:config completion:^(WPRemoteConfig *config, NSError *fetchError) {
                if (fetchError) {
                    completion(nil, fetchError);
                    return;
                }
                completion(config, nil);
            }];
            return;
        }
        BOOL higherVersionExists = NSOrderedAscending == [WPRemoteConfig compareVersion:config.version withVersion:highestVersion];
        BOOL shouldFetch = higherVersionExists;
        NSString *shouldFetchVersion = highestVersion;
        
        // Do not fetch too often
        NSTimeInterval configAge = -[config.fetchDate timeIntervalSinceNow];
        if (shouldFetch && configAge < self.minimumConfigAge) {
            shouldFetch = NO;
        }
        
        // Force fetch if expired
        if (!shouldFetch && configAge > self.maximumConfigAge) {
            shouldFetch = YES;
            if (!higherVersionExists) shouldFetchVersion = config.version;
        }

        // Do not fetch too often
        if (shouldFetch && self.lastFetchDate && lastFetchInterval < self.minimumFetchInterval) {
            shouldFetch = NO;
        }

        if (!shouldFetch) {
            completion(config, nil);
            return;
        }
        
        [self fetchAndStoreConfigWithVersion:shouldFetchVersion currentConfig:config completion:^(WPRemoteConfig *config, NSError *error) {
            completion(config, error);
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

- (void) storeConfig:(WPRemoteConfig *)config completion:(void (^)(NSError *))completion {
    [self.remoteConfigStorage storeRemoteConfig:config completion:^(NSError *error) {
        self.storedConfig = config;
        completion(error);
    }];
}

- (void) fetchAndStoreConfigWithVersion:(NSString * _Nullable)version currentConfig:(WPRemoteConfig * _Nullable)currentConfig completion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    self.lastFetchDate = [NSDate date];
    [self.remoteConfigFetcher fetchConfigWithVersion:version completion:^(WPRemoteConfig *newConfig, NSError *fetchError) {
        if (newConfig && !fetchError) {
            if (currentConfig && [currentConfig hasHigherVersionThan:newConfig]) {
                if (completion) completion(currentConfig, nil);
                return;
            }
            [self.remoteConfigStorage storeRemoteConfig:newConfig completion:^(NSError *storageError) {
                if (storageError) {
                    WPLog(@"Could not store RemoteConfig in storage: %@", storageError.description);
                    if (completion) completion(nil, storageError);
                } else {
                    self.storedConfig = newConfig;
                    [self.remoteConfigStorage declareVersion:newConfig.version completion:^(NSError *declareVersionError) {
                        if (declareVersionError) {
                            WPLog(@"Error declaring version to storate: %@", declareVersionError.description);
                        }
                        [[NSNotificationCenter defaultCenter] postNotificationName:WPRemoteConfigUpdatedNotification object:newConfig];
                        if (completion) completion(newConfig, nil);
                    }];
                }
            }];
            return;
        }
        if (fetchError) {
            WPLog(@"Could not fetch RemoteConfig from server: %@", fetchError.description);
        }
        if (completion) completion(nil, fetchError);
    }];
}

@end