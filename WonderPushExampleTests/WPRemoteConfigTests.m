//
//  WPRemoteConfigTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPRemoteConfig.h"
#import "WPSemver.h"
#import "WPUtil.h"

@interface WPRemoteConfig ()
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate maxAge:(NSTimeInterval)maxAge;
- (instancetype) initWithData:(NSDictionary *)data version:(NSString *)version fetchDate:(NSDate *)fetchDate maxAge:(NSTimeInterval)maxAge minAge:(NSTimeInterval)minAge;
@end

@interface MockRemoteConfigFetcher : NSObject<WPRemoteConfigFetcher>
@property (nonatomic, nullable, strong) WPRemoteConfig *fetchedConfig;
@property (nonatomic, nullable, strong) NSError *error;
@property (nonatomic, nullable, strong) NSString *lastRequestedVersion;
@property (nonatomic, nullable, strong) NSDate *lastRequestedDate;
@end

@interface MockRemoteConfigStorage : NSObject<WPRemoteConfigStorage>
@property (nonatomic, nullable, strong) WPRemoteConfig *storedConfig;
@property (nonatomic, nullable, strong) NSString *storedHighestVersion;
@property (nonatomic, nullable, strong) NSError *error;
- (void) reset;
@end

@interface MockAsyncRemoteConfigFetcher : NSObject<WPRemoteConfigFetcher>
@property (nonatomic, nullable, strong) void (^completion)(WPRemoteConfig * _Nullable, NSError * _Nullable);
@property (nonatomic, nullable, strong) NSString *lastRequestedVersion;
@property (nonatomic, nullable, strong) NSDate *lastRequestedDate;
- (void) resolveWithConfig:(WPRemoteConfig * _Nullable)config error:(NSError * _Nullable)error;
@end

@implementation MockRemoteConfigFetcher

- (void) fetchConfigWithVersion:(NSString *)version completion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    self.lastRequestedVersion = version;
    self.lastRequestedDate = [NSDate date];
    completion(self.fetchedConfig, self.error);
}

@end

@implementation MockRemoteConfigStorage

- (void) storeRemoteConfig:(WPRemoteConfig *)remoteConfig
                completion:(void (^)(NSError * _Nullable))completion {
    self.storedConfig = remoteConfig;
    completion(self.error);
}

- (void)declareVersion:(nonnull NSString *)version completion:(nonnull void (^)(NSError * _Nullable))completion {
    if (!self.storedHighestVersion || [WPRemoteConfig compareVersion:self.storedHighestVersion withVersion:version] == NSOrderedAscending) {
        self.storedHighestVersion = version;
    }
    completion(self.error);
}


- (void)loadRemoteConfigAndHighestDeclaredVersionWithCompletion:(nonnull void (^)(WPRemoteConfig * _Nullable, NSString * _Nullable, NSError * _Nullable))completion {
    completion(self.storedConfig, self.storedHighestVersion, self.error);
}


- (void) reset {
    self.storedConfig = nil;
    self.error = nil;
}

@end

@implementation MockAsyncRemoteConfigFetcher

- (void) fetchConfigWithVersion:(NSString *)version completion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    self.lastRequestedDate = [NSDate new];
    self.lastRequestedVersion = version;
    self.completion = completion;
}

- (void) resolveWithConfig:(WPRemoteConfig *)config error:(NSError *)error {
    if (self.completion) self.completion(config, error);
}

@end

@interface WPRemoteConfigTests : XCTestCase
@property (nonatomic, strong, nonnull) MockRemoteConfigFetcher *fetcher;
@property (nonatomic, strong, nonnull) MockRemoteConfigStorage *storage;
@property (nonatomic, strong, nonnull) WPRemoteConfigManager *manager;
@end

@implementation WPRemoteConfigTests

- (void)setUp {
    
    self.fetcher = [MockRemoteConfigFetcher new];
    self.storage = [MockRemoteConfigStorage new];
    self.manager = [[WPRemoteConfigManager alloc] initWithRemoteConfigFetcher:self.fetcher storage:self.storage];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/**
 First time use of a manager declareVersion should trigger a download
 */
- (void)testInitialDeclareVersion {
    XCTAssertNil(self.fetcher.fetchedConfig);
    XCTAssertNil(self.storage.storedConfig);
    WPRemoteConfig *remoteConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0"];
    self.fetcher.fetchedConfig = remoteConfig;
    [self.manager declareVersion:@"1.0.0"];
    
    // Declaring the version should trigger a fetch
    XCTAssertNotNil(self.fetcher.lastRequestedDate);
    XCTAssertEqualObjects(self.fetcher.lastRequestedVersion, @"1.0.0");
    XCTAssertEqual(self.storage.storedConfig, remoteConfig);

    // The manager should have called storage to remember the highest declared version
    XCTAssertEqualObjects(self.storage.storedHighestVersion, @"1.0.0");
}

- (void)testInitialRead {
    XCTAssertNil(self.fetcher.fetchedConfig);
    XCTAssertNil(self.storage.storedConfig);
    WPRemoteConfig *remoteConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0"];
    self.fetcher.fetchedConfig = remoteConfig;
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"read"];
    [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
        XCTAssertEqualObjects(conf.version, @"1.0.0");
        // We don't know what version is out there
        XCTAssertNil(self.fetcher.lastRequestedVersion);
        XCTAssertNil(error);
        XCTAssertEqual(self.storage.storedConfig, conf);
        XCTAssertEqual(self.fetcher.fetchedConfig, conf);
        [expectation fulfill];
    }];
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:0.5];
}

/**
 Ensure we never fetch config more than once every `minimumFetchInterval`,
 and we don't consider new versions until `minimumConfigAge` is reached.
 */
- (void)testRateLimiting {
    self.manager.minimumConfigAge = 0.25;
    self.manager.maximumConfigAge = 10;
    self.manager.minimumFetchInterval = 1;
    
    // A brand new config, just fetched
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[NSDate date]];
    
    // A fetcher ready to serve an even fresher config
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.1"];
    
    // Yet, we'll get 1.0.0 because it's not expired yet and we haven't declared a newer version.
    [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
        XCTAssertEqualObjects(conf.version, @"1.0.0");
    }];
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Declare a newer version
    [self.manager declareVersion:@"1.0.1"];
    XCTAssertEqualObjects(self.storage.storedHighestVersion, @"1.0.1");
    
    // We won't consider this version until minimumConfigAge and minimumFetchInterval are reached.
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Try to get the config
    [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
        // Should still be 1.0.0 because we haven't reached minimumConfigAge and minimumFetchInterval yet
        XCTAssertEqualObjects(conf.version, @"1.0.0");
        XCTAssertNil(self.fetcher.lastRequestedDate);
    }];
    
    // Wait for the minimumConfigAge and try again, a fetch should happen,
    // just because we declared a higher version.
    NSTimeInterval waitTime1 = 2 * self.manager.minimumConfigAge;
    NSTimeInterval waitTime2 = (self.manager.minimumFetchInterval) * 2;

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"minimumFetchInterval second passed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        // Meanwhile, nothing should have happened
        XCTAssertNil(self.fetcher.lastRequestedDate);
        
        // Read
        [self.manager read:^(WPRemoteConfig *conf, NSError *error) {

            // A fetch just happened
            XCTAssertEqualObjects(conf.version, @"1.0.1");
            XCTAssertNil(error);
            XCTAssertNotNil(self.fetcher.lastRequestedDate);
            
            // Declare an even newer version right now, no fetch should happen because minimumFetchInterval still not reached
            // Disclaimer: because the fetchDate of the 1.0.1 version is the same as 1.0.0, it's reached its configMaxAge
            self.fetcher.lastRequestedDate = nil;
            [self.manager declareVersion:@"1.0.2"];
            XCTAssertNil(self.fetcher.lastRequestedDate);
            
            // Wait minimumFetchInterval
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
                    
                    // A fetch happened
                    XCTAssertNotNil(self.fetcher.lastRequestedDate);

                    // Finish the test
                    [expectation fulfill];
                }];
            });
            
        }];
        
    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2 * (waitTime1 + waitTime2)];
}

/**
 Ensure we don't fetch a new version of the config as long as maximumFetchInterval is not reached and a new version hasn't been declared.
 */
- (void) testCaching {
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 2;
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[NSDate now]];
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.1" fetchDate:[NSDate now]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"read"];
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0.0");
        [expectation fulfill];
    }];
    XCTAssertNil(self.fetcher.lastRequestedDate);
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:0.5];
}

- (void) testVersionNumbers {
    XCTAssertTrue([WPSemver semverWithString:@"0"].isValid);
    XCTAssertTrue([WPSemver semverWithString:@"1"].isValid);
    XCTAssertTrue([WPSemver semverWithString:@"1234"].isValid);
    
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"1589987090471" withVersion:@"1589987090472"]);
}
/**
 Ensure we fetch config when isExpired is true
 */

- (void) testIsExpired {
    // Remove rate limiting
    self.manager.minimumFetchInterval = 0;
    
    // Make a config that expires in 100ms
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0" fetchDate:[NSDate date] maxAge:0.1];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.101 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertTrue(self.storage.storedConfig.isExpired);
        XCTAssertNil(self.fetcher.lastRequestedDate);
        [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
            XCTAssertNotNil(self.fetcher.lastRequestedDate);
            [expectation fulfill];
        }];
    });
    
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:0.5];
}
/**
 Ensure we fetch config when the max fetch interval is reached.
 */
- (void) testMaximumFetchInterval {
    self.manager.minimumConfigAge = 0.1;
    self.manager.maximumConfigAge = 1;
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[[NSDate now] dateByAddingTimeInterval:-1.1]];
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.1" fetchDate:[NSDate now]];
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0.1");
    }];
    XCTAssertNotNil(self.fetcher.lastRequestedDate);
}

/**
 Verify we immediately fetch config when minimumFetchInterval is 0 and a new version is declared.
 */
- (void) testZeroMinimumFetchInterval {
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 2;
    self.manager.minimumFetchInterval = 0;
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[NSDate date]];
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.1"];
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Declare new version
    [self.manager declareVersion:@"1.0.1"];
    
    // Verify a fetch happened
    XCTAssertNotNil(self.fetcher.lastRequestedDate);
    
    // Verify the version is now 1.0.1
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0.1");
    }];
}
/**
 Verify we only fetch when the version goes up.
 */
- (void) testVersionIncrement {
    self.manager.minimumConfigAge = 0.5;
    self.manager.minimumFetchInterval = 0.5;
    self.manager.maximumConfigAge = 10; // We don't want to reach this
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[[NSDate date] dateByAddingTimeInterval:-5]]; // Older than minimumConfigAge
    
    // No fetch yet
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Declare earlier version
    [self.manager declareVersion:@"0.1"];
    
    // Still no fetch because the version is too low
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Let's declare a later version but download an earlier version (which is possible because of network caches, the API can way a new version is available, yet caches are not up to date yet)

    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"0.1" fetchDate:[NSDate date]];
    [self.manager declareVersion:@"1.0.1"];
    XCTAssertEqualObjects(self.storage.storedHighestVersion, @"1.0.1");
    
    // A fetch should have happened
    XCTAssertNotNil(self.fetcher.lastRequestedDate);
    
    // Yet, when we read, the version should still be 1.0.0 because we fetched version 0.1
    // And no fetch should happen (it's too early)
    self.fetcher.lastRequestedDate = nil;
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertNil(self.fetcher.lastRequestedDate);
        XCTAssertEqualObjects(config.version, @"1.0.0");
    }];
    
    // Wait for minimumFetchInterval, there should be a fetch when we read
    NSTimeInterval waitTime = 2 * self.manager.minimumFetchInterval;
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"minimumFetchInterval second passed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertNil(self.fetcher.lastRequestedDate);
        [self.manager read:^(WPRemoteConfig *config, NSError *error) {

            // Version is still 1.0.0
            XCTAssertEqualObjects(config.version, @"1.0.0");

            // We should have tried to fetch though
            XCTAssertNotNil(self.fetcher.lastRequestedDate);
            
            [expectation fulfill];
        }];

    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2 * waitTime];
}

/**
 Checks that the highest declared version is well maintained between what is declared and what is fetched.
 */
- (void) testDeclaredVersion {
    self.manager.minimumConfigAge = 0;
    self.manager.minimumFetchInterval = 0;
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0"];
    [self.manager declareVersion:@"1.0.1"];
    XCTAssertEqualObjects(self.storage.storedHighestVersion, @"1.0.1");
    
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.3"];
    [self.manager declareVersion:@"1.0.2"];
    XCTAssertEqualObjects(self.storage.storedHighestVersion, @"1.0.3");
}

/**
 Verify WPRemoteConfigUpdatedNotification happens
 */
- (void) testNotification {
    __block NSNotification *notification = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:WPRemoteConfigUpdatedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        notification = note;
    }];
    
    XCTAssertNil(notification);
    
    WPRemoteConfig *fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0"];
    self.fetcher.fetchedConfig = fetchedConfig;
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {}];
    XCTAssertNotNil(notification);
    XCTAssertEqual(notification.object, fetchedConfig);    
}

/**
 Verify WPRemoteConfigUpdatedNotification doesn't happen when we fetch the same version
 */

- (void) testNotificationSameVersion {
    __block NSNotification *notification = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:WPRemoteConfigUpdatedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        notification = note;
    }];
    
    XCTAssertNil(notification);
    
    WPRemoteConfig *storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0"];
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 0;
    self.manager.minimumFetchInterval = 0;
    self.storage.storedConfig = storedConfig;
    self.fetcher.fetchedConfig = storedConfig;
    [self.manager declareVersion:@"1.0.1"];
    XCTAssertNotNil(self.fetcher.lastRequestedDate);
    XCTAssertNil(notification);
}
/**
 Verify version comparison
 */
- (void) testVersionComparison {
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"1.0.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"1.0.0" withVersion:@"1.0.1"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0.0" withVersion:@"0.9"]);

    // With "v" prefix
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"v1.0" withVersion:@"v1.0.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"v1.0.0" withVersion:@"v1.0.1"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"v1.0.0" withVersion:@"v0.9"]);

    // With or without "v" prefix
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"v1.0.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"1.0.0" withVersion:@"v1.0.1"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0.0" withVersion:@"v0.9"]);

    // With invalid version
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"z"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"_"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"/"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"!"]);
    XCTAssertEqual(NSOrderedDescending, [WPRemoteConfig compareVersion:@"1.0" withVersion:@"."]);


    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"z" withVersion:@"1.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"_" withVersion:@"1.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"/" withVersion:@"1.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"!" withVersion:@"1.0"]);
    XCTAssertEqual(NSOrderedAscending, [WPRemoteConfig compareVersion:@"." withVersion:@"1.0"]);


    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"z" withVersion:@"/"]);
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"_" withVersion:@"/"]);
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"/" withVersion:@"/"]);
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"!" withVersion:@"/"]);
    XCTAssertEqual(NSOrderedSame, [WPRemoteConfig compareVersion:@"." withVersion:@"/"]);
}

/**
 When the same version of the config is fetched a second time, its fetch date should be updated.
 */
- (void) testUpdateConfigAge {
    self.manager.minimumFetchInterval = 0;
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 10;
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0"];

    __block NSDate *fetchDate = nil;
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        fetchDate = config.fetchDate;
    }];

    XCTAssertNotNil(fetchDate);
    XCTAssert(-[fetchDate timeIntervalSinceNow] < 0.1);
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // We're fetching a config with the same version and a more recent fetch date
        self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{}
                                                                  version:@"1.0"
                                                                fetchDate:[NSDate date]];
        [self.manager declareVersion:@"1.0.1"];
        [self.manager read:^(WPRemoteConfig *config, NSError *error) {
            XCTAssert([config.fetchDate timeIntervalSinceDate:fetchDate] >= 1);
            [expectation fulfill];
        }];
    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}

/**
 When a version is declared, that is the same as the current stored config, its fetch date should be updated.
 */
- (void) testUpdateConfigAge2 {
    self.manager.minimumFetchInterval = 0;
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 10;
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0"];

    __block NSDate *fetchDate = nil;
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        fetchDate = config.fetchDate;
    }];

    XCTAssertNotNil(fetchDate);
    XCTAssert(-[fetchDate timeIntervalSinceNow] < 0.1);
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.fetcher.lastRequestedVersion = nil;
        [self.manager declareVersion:@"1.0"];
        XCTAssertNil(self.fetcher.lastRequestedVersion);
        [self.manager read:^(WPRemoteConfig *config, NSError *error) {
            XCTAssert([config.fetchDate timeIntervalSinceDate:fetchDate] >= 1);
            [expectation fulfill];
        }];
    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}

/**
 When a version is declared, that is earlier as the stored config's version, its fetch date should NOT be updated.
 This is the opposite of testUpdateConfigAge2.
 */
- (void) testUpdateConfigAge3 {
    self.manager.minimumFetchInterval = 0;
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 10;
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0"];

    __block NSDate *fetchDate = nil;
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        fetchDate = config.fetchDate;
    }];

    XCTAssertNotNil(fetchDate);
    XCTAssert(-[fetchDate timeIntervalSinceNow] < 0.1);
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.fetcher.lastRequestedVersion = nil;
        [self.manager declareVersion:@"0.1"];
        [self.manager read:^(WPRemoteConfig *config, NSError *error) {
            XCTAssertEqualObjects(config.fetchDate, fetchDate);
            [expectation fulfill];
        }];
    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}


- (void) testSerialize {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *configURL = [bundle URLForResource:@"remote-config-example" withExtension:@"json"];
    NSData *configData = [NSData dataWithContentsOfURL:configURL];
    NSDate *fetchDate = [NSDate date];
    NSError *JSONError = nil;
    id configJSON = [NSJSONSerialization JSONObjectWithData:configData options:0 error:&JSONError];
    id version = [configJSON valueForKey:@"version"];
    if ([version isKindOfClass:NSNumber.class]) version = [version stringValue];

    NSNumber *maxAgeNumber = [configJSON valueForKey:@"maxAge"];
    XCTAssertNil(JSONError);
    XCTAssertEqualObjects(version, @"2");
    XCTAssertEqualObjects(maxAgeNumber, @123456);

    WPRemoteConfig *remoteConfig = [[WPRemoteConfig alloc] initWithData:configJSON version:version fetchDate:fetchDate maxAge: maxAgeNumber.doubleValue / 1000];
    NSError *archiverError = nil;
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:remoteConfig requiringSecureCoding:YES error:&archiverError];
    XCTAssertNotNil(encoded);
    XCTAssertNil(archiverError);
    
    WPRemoteConfig *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:WPRemoteConfig.class fromData:encoded error:&archiverError];
    XCTAssertNil(archiverError);
    XCTAssertNotNil(decoded);

    XCTAssertEqualObjects(remoteConfig.version, decoded.version);
    XCTAssertEqualObjects(remoteConfig.fetchDate, decoded.fetchDate);
    XCTAssertEqualObjects(fetchDate, decoded.fetchDate);
    XCTAssertEqual(remoteConfig.maxAge, decoded.maxAge);
    XCTAssertEqual(remoteConfig.maxAge, 123.456);
    XCTAssertEqualObjects(remoteConfig.data[@"version"], decoded.data[@"version"]);
}

- (void) testUserDefaultsStorage {
    NSString *clientId = @"unittestsclientid";
    WPRemoteConfigStorateWithUserDefaults *storage = [[WPRemoteConfigStorateWithUserDefaults alloc] initWithClientId:clientId];
    
    // Clean defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:[WPRemoteConfigStorateWithUserDefaults remoteConfigKeyWithClientId:clientId]];
    [defaults removeObjectForKey:[WPRemoteConfigStorateWithUserDefaults versionsKeyWithClientId:clientId]];
    [defaults synchronize];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    
    NSDate *now = [NSDate date];
    WPRemoteConfig *config = [[WPRemoteConfig alloc] initWithData:@{@"toto": @"titi"} version:@"1.0.0" fetchDate:now];
    [storage storeRemoteConfig:config completion:^(NSError *error) {
        XCTAssertNil(error);
        [storage declareVersion:@"1.2.3" completion:^(NSError *error) {
            XCTAssertNil(error);
            [storage declareVersion:@"1.0.0" completion:^(NSError *error) {
                XCTAssertNil(error);
                [storage loadRemoteConfigAndHighestDeclaredVersionWithCompletion:^(WPRemoteConfig *loadedConfig, NSString *highestVersion, NSError *error) {
                    XCTAssertNil(error);
                    XCTAssertEqualObjects(@"1.2.3", highestVersion);
                    XCTAssertEqualObjects(@"titi", loadedConfig.data[@"toto"]);
                    [expectation fulfill];
                }];
            }];
        }];
    }];
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];

}

/**
 Ensures that when we request the config and it is currently fetching, we wait for the result.
 */
- (void) testConcurrentFetches {
    
    // The async fetcher lets us call the completion handler ourselves.
    MockAsyncRemoteConfigFetcher *fetcher = [MockAsyncRemoteConfigFetcher new];
    self.manager.remoteConfigFetcher = fetcher;
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    expectation.expectedFulfillmentCount = 2;

    WPRemoteConfig *resultConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1"];
    
    // Read
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertNotNil(config);
        XCTAssertEqual(config, resultConfig);
        [expectation fulfill];
    }];
    
    // A new fetch should have been triggered
    XCTAssertNotNil(fetcher.completion);
    id completion = fetcher.completion;

    // Read again before result comes
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertNotNil(config);
        XCTAssertEqual(config, resultConfig);
        [expectation fulfill];
    }];
    
    // A new fetch hasn't been requested
    XCTAssertEqual(completion, fetcher.completion);
    
    // Let's resolve, which should resolve the above read.
    [fetcher resolveWithConfig:resultConfig error:nil];

    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];

}

- (void)testWithJSON {
    NSError *error = nil;
    WPRemoteConfig *config;
    
    // Missing version
    config = [WPRemoteConfig withJSON:@{} error:&error];
    XCTAssertNil(config);
    XCTAssertEqual(error.code, WPErrorInvalidFormat);
    
    // With version
    error = nil;
    config = [WPRemoteConfig withJSON:@{
        @"version": @"1.0.1"
    } error:&error];
    XCTAssertEqualObjects(config.version, @"1.0.1");
    XCTAssertNil(error);

    // TTL
    error = nil;
    config = [WPRemoteConfig withJSON:@{
        @"version": @"1.0.1",
        @"maxAge": @123456
    } error:&error];
    XCTAssertEqual(config.maxAge, 123.456);
    XCTAssertNil(error);

    // TTL, alt syntax
    error = nil;
    config = [WPRemoteConfig withJSON:@{
        @"version": @"1.0.1",
        @"cacheTtl": @123456
    } error:&error];
    XCTAssertEqual(config.maxAge, 123.456);
    XCTAssertNil(error);

    // minAge
    error = nil;
    config = [WPRemoteConfig withJSON:@{
        @"version": @"1.0.1",
        @"minAge": @123456
    } error:&error];
    XCTAssertEqual(config.minAge, 123.456);
    XCTAssertNil(error);
}

/**
 checks that minAge specified at config level is effective.
 */
- (void)testConfigMinAge {
    self.manager.minimumConfigAge = 0;
    self.manager.maximumConfigAge = 10;
    self.manager.minimumFetchInterval = 1;
    
    // A brand new config, just fetched
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[NSDate date] maxAge:0 minAge:0.25];
    
    // A fetcher ready to serve an even fresher config
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.1"];
    
    [self.manager declareVersion:@"1.0.1"];

    // Yet, we'll get 1.0.0 because minAge hasn't been reached.
    [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
        XCTAssertEqualObjects(conf.version, @"1.0.0");
    }];
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];

    // Wait for a little more than minAge
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.manager read:^(WPRemoteConfig *config, NSError *error) {
            XCTAssertEqualObjects(config.version, @"1.0.1");
            [expectation fulfill];
        }];
    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];

}

/**
 Defines behavior when a 404 on the config occurs.
 */
- (void) test404 {
    self.fetcher.error = [[NSError alloc] initWithDomain:@"test" code:1 userInfo:nil];
    self.fetcher.fetchedConfig = nil;
    self.manager.minimumFetchInterval = 0.1;
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];

    [self.manager read:^(WPRemoteConfig *config, NSError *e1) {

        // no config, get an error, updated requested date
        XCTAssertNil(config);
        XCTAssertNotNil(e1);
        XCTAssertNotNil(self.fetcher.lastRequestedDate);
        
        self.fetcher.lastRequestedDate = nil;

        [self.manager read:^(WPRemoteConfig *config, NSError *e2) {

            XCTAssertNil(config);

            // We haven't made a fetch, so no error, and no requested date
            XCTAssertNil(e2);
            XCTAssertNil(self.fetcher.lastRequestedDate);
            
            // Wait for minimumFetchInterval
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.manager read:^(WPRemoteConfig *config, NSError *e3) {
                    XCTAssertNil(config);
                    // We've made a fetch, so error and lastRequestedDate are not nil
                    XCTAssertNotNil(e3);
                    XCTAssertNotNil(self.fetcher.lastRequestedDate);
                    [expectation fulfill];
                }];
            });

        }];
    }];
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}

/**
 Verifies that when a fetch error occurs, we serve a previously fetched config.
 */
- (void) testFetchError {
    
    // Fetch as often as we like
    self.manager.minimumConfigAge = 0;
    self.manager.minimumFetchInterval = 0;
    
    // Configure a previously fetched config
    self.storage.storedConfig = [WPRemoteConfig withJSON:@{
        @"version": @"1.0",
    } error:nil];
    
    // Configure fetch error
    self.fetcher.error = [NSError errorWithDomain:@"some" code:1 userInfo:nil];
    
    // Declare a higher version
    [self.manager declareVersion:@"1.1"];
    
    // Read
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        // We're serving the previous config
        XCTAssertEqualObjects(config.version, @"1.0");
        // We're also reporting the error
        XCTAssertEqualObjects(error.domain, @"some");
    }];
}
/**
 Checks that when a particular config entry is present, no new configuration will ever be fetched
 */
- (void) testDisableFetch {

    // Fetch as often as we like
    self.manager.minimumConfigAge = 0;
    self.manager.minimumFetchInterval = 0;
    
    // A config has already been fetched, that forbids further fetching via the WP_REMOTE_CONFIG_DISABLE_FETCH_KEY
    self.storage.storedConfig = [WPRemoteConfig withJSON:@{
        @"version": @"1.0",
        @"maxAge": @123456,
        WP_REMOTE_CONFIG_DISABLE_FETCH_KEY: @YES,
    } error:nil];
    
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0");
        XCTAssertNil(self.fetcher.lastRequestedDate);
    }];
    
    // Declare new version
    [self.manager declareVersion:@"1.1"];

    // No fetch should have happened
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0");
        XCTAssertNil(self.fetcher.lastRequestedDate);
    }];
}
@end
