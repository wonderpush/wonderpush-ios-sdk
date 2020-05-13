//
//  WPRemoteConfigTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 13/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPRemoteConfig.h"

@interface MockRemoteConfigFetcher : NSObject<WPRemoteConfigFetcher>
@property (nonatomic, nullable, strong) WPRemoteConfig *fetchedConfig;
@property (nonatomic, nullable, strong) NSError *error;
@property (nonatomic, nullable, strong) NSString *lastRequestedVersion;
@property (nonatomic, nullable, strong) NSDate *lastRequestedDate;
@end

@interface MockRemoteConfigStorage : NSObject<WPRemoteConfigStorage>
@property (nonatomic, nullable, strong) WPRemoteConfig *storedConfig;
@property (nonatomic, nullable, strong) NSError *error;
- (void) reset;
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

- (void) loadRemoteConfigWithCompletion:(void (^)(WPRemoteConfig * _Nullable, NSError * _Nullable))completion {
    completion(self.storedConfig, self.error);
}

- (void) reset {
    self.storedConfig = nil;
    self.error = nil;
}

@end

@interface WPRemoteConfigTests : XCTestCase
@property (nonatomic, strong, nonnull) MockRemoteConfigFetcher *fetcher;
@property (nonatomic, strong, nonnull) MockRemoteConfigStorage *storage;
@property (nonatomic, strong, nonnull) WPRemoteConfigManager *manager;
@end

@implementation WPRemoteConfigTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
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
    XCTAssertEqualObjects(self.fetcher.lastRequestedVersion, @"1.0.0");
    XCTAssertEqual(self.storage.storedConfig, remoteConfig);
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
 Ensure we never fetch config until the minimum fetch interval is reached.
 */
- (void)testMinimumInterval {
    self.manager.minimumFetchInterval = 1;
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[NSDate date]];
    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.1"];
    [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
        XCTAssertEqualObjects(conf.version, @"1.0.0");
    }];
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Declare a later version
    [self.manager declareVersion:@"1.0.1"];
    
    // Check that no download happened
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Try to get the config
    [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
        // Should still be 1.0.0 because we haven't reached minimumFetchInterval yet
        XCTAssertEqualObjects(conf.version, @"1.0.0");
        XCTAssertNil(self.fetcher.lastRequestedDate);
    }];
    
    // Wait for the minimumFetchInterval and try again, a fetch should happen
    NSTimeInterval waitTime = 2 * self.manager.minimumFetchInterval;
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"minimumFetchInterval second passed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(waitTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        // Nothing should have happened yet
        XCTAssertNil(self.fetcher.lastRequestedDate);
        
        // Read
        [self.manager read:^(WPRemoteConfig *conf, NSError *error) {
            // Verify a fetch happened
            XCTAssertEqualObjects(conf.version, @"1.0.1");
            XCTAssertNil(error);
            XCTAssertNotNil(self.fetcher.lastRequestedDate);

            // Finish the test
            [expectation fulfill];
        }];
        
    });
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2 * waitTime];
}

/**
 Ensure we don't fetch a new version of the config as long as maximumFetchInterval is not reached and a new version hasn't been declared.
 */
- (void) testCaching {
    self.manager.minimumFetchInterval = 0;
    self.manager.maximumFetchInterval = 2;
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

/**
 Ensure we fetch config when the max fetch interval is reached.
 */
- (void) testMaximumFetchInterval {
    self.manager.minimumFetchInterval = 0.1;
    self.manager.maximumFetchInterval = 1;
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[[NSDate now] dateByAddingTimeInterval:-1.01]];
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
    self.manager.minimumFetchInterval = 0;
    self.manager.maximumFetchInterval = 2;
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
    self.manager.minimumFetchInterval = 0.5;
    self.manager.maximumFetchInterval = 10; // We don't want to reach this
    self.storage.storedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"1.0.0" fetchDate:[[NSDate date] dateByAddingTimeInterval:-5]];
    
    // No fetch yet
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Declare earlier version
    [self.manager declareVersion:@"0.1"];
    
    // Still no fetch because the version is too low
    XCTAssertNil(self.fetcher.lastRequestedDate);
    
    // Let's declare a later version but download an earlier version (which is possible because of network caches, the API can way a new version is available, yet caches are not up to date yet)

    self.fetcher.fetchedConfig = [[WPRemoteConfig alloc] initWithData:@{} version:@"0.1" fetchDate:[NSDate date]];
    [self.manager declareVersion:@"1.0.1"];
    
    // A fetch should have happened
    XCTAssertNotNil(self.fetcher.lastRequestedDate);
    
    // Yet, when we read, the version should still be 1.0.0
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0.0");
    }];
    
    // Let's nil-out the self.fetcher.lastRequestedDate and request another read.
    // There shouldn't be a fetch before minimumFetchInterval is reached
    self.fetcher.lastRequestedDate = nil;
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        XCTAssertEqualObjects(config.version, @"1.0.0");
        XCTAssertNil(self.fetcher.lastRequestedDate);
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
@end
