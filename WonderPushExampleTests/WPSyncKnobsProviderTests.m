//
//  WPSyncKnobsProviderTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncKnobsProvider (issue wonderpush-ios-sdk-i2x.13): deriving effective sync
// knobs from a WPRemoteConfig, and the async readKnobs: path over WPRemoteConfigManager.

#import <XCTest/XCTest.h>
#import "WPSyncKnobsProvider.h"
#import "WPSyncKnobs.h"
#import "WPRemoteConfig.h"

// Expose the private designated initializer (same approach as WPRemoteConfigTests).
@interface WPRemoteConfig (Testing)
- (instancetype)initWithData:(NSDictionary *)data version:(NSString *)version;
@end

// Minimal synchronous fetcher/storage so manager read: resolves deterministically with our config.
@interface FakeKnobsFetcher : NSObject <WPRemoteConfigFetcher>
@property (nonatomic, strong, nullable) WPRemoteConfig *config;
@property (nonatomic, strong, nullable) NSError *error;
@end
@implementation FakeKnobsFetcher
- (void)fetchConfigWithVersion:(NSString *)version completion:(WPRemoteConfigReadCompletionHandler)completion {
    completion(self.config, self.error);
}
@end

@interface FakeKnobsStorage : NSObject <WPRemoteConfigStorage>
@end
@implementation FakeKnobsStorage
- (void)storeRemoteConfig:(WPRemoteConfig *)remoteConfig completion:(void (^)(NSError *_Nullable))completion { completion(nil); }
- (void)declareVersion:(NSString *)version completion:(void (^)(NSError *_Nullable))completion { completion(nil); }
- (void)loadRemoteConfigAndHighestDeclaredVersionWithCompletion:(void (^)(WPRemoteConfig *_Nullable, NSString *_Nullable, NSError *_Nullable))completion {
    completion(nil, nil, nil);   // nothing stored -> manager fetches
}
@end

@interface WPSyncKnobsProviderTests : XCTestCase
@end

@implementation WPSyncKnobsProviderTests

- (WPRemoteConfig *)configWithData:(NSDictionary *)data {
    return [[WPRemoteConfig alloc] initWithData:data version:@"1.0.0"];
}

#pragma mark - pure derivation

- (void)testNilConfigYieldsDefaults {
    XCTAssertEqualObjects([WPSyncKnobsProvider knobsFromRemoteConfig:nil], [WPSyncKnobs defaultKnobs]);
}

- (void)testEmptyConfigYieldsDefaults {
    XCTAssertEqualObjects([WPSyncKnobsProvider knobsFromRemoteConfig:[self configWithData:@{}]], [WPSyncKnobs defaultKnobs]);
}

- (void)testOverridesApplied {
    WPSyncKnobs *k = [WPSyncKnobsProvider knobsFromRemoteConfig:[self configWithData:@{
        @"syncWeakSignalDebounceMs": @1234,
        @"syncMutexTtlMs": @30000,
        @"syncMaxLastReadDateAgeMs": @5000,
    }]];
    XCTAssertEqual(k.weakSyncSignalDebounceMs, 1234.0);
    XCTAssertEqual(k.mutexTtlMs, 30000.0);
    XCTAssertEqual(k.maxLastReadDateAgeMs, 5000.0);
    XCTAssertTrue(isinf(k.maxLastSyncDateAgeMs));   // untouched cap stays infinite
}

- (void)testKillSwitch {
    XCTAssertFalse([WPSyncKnobsProvider knobsFromRemoteConfig:[self configWithData:@{@"syncOpportunisticInjection": @NO}]].opportunisticInjectionEnabled);
    XCTAssertTrue([WPSyncKnobsProvider knobsFromRemoteConfig:[self configWithData:@{@"syncOpportunisticInjection": @YES}]].opportunisticInjectionEnabled);
}

- (void)testUnrelatedConfigKeysIgnored {
    // Real remote-config keys alongside sync ones: only the sync* keys affect the knobs.
    WPSyncKnobs *k = [WPSyncKnobsProvider knobsFromRemoteConfig:[self configWithData:@{
        @"disableJsonSync": @YES,
        @"trackEventsForNonSubscribers": @YES,
        @"syncWeakSignalDebounceMs": @777,
    }]];
    XCTAssertEqual(k.weakSyncSignalDebounceMs, 777.0);
    XCTAssertEqualObjects([k toDictionary][@"maxInboxEntries"], @1000);   // default preserved
}

#pragma mark - async read over the manager

- (WPSyncKnobsProvider *)providerReturningConfig:(WPRemoteConfig *)config error:(NSError *)error {
    FakeKnobsFetcher *fetcher = [FakeKnobsFetcher new];
    fetcher.config = config;
    fetcher.error = error;
    WPRemoteConfigManager *manager = [[WPRemoteConfigManager alloc] initWithRemoteConfigFetcher:fetcher
                                                                                        storage:[FakeKnobsStorage new]];
    return [[WPSyncKnobsProvider alloc] initWithRemoteConfigManager:manager];
}

- (void)testReadKnobsMergesFetchedConfig {
    WPSyncKnobsProvider *provider = [self providerReturningConfig:[self configWithData:@{@"syncWeakSignalDebounceMs": @1234}] error:nil];
    XCTestExpectation *exp = [self expectationWithDescription:@"readKnobs"];
    [provider readKnobs:^(WPSyncKnobs *knobs) {
        XCTAssertEqual(knobs.weakSyncSignalDebounceMs, 1234.0);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:2];
}

- (void)testReadKnobsFallsBackToDefaultsWhenNoConfig {
    WPSyncKnobsProvider *provider = [self providerReturningConfig:nil error:nil];
    XCTestExpectation *exp = [self expectationWithDescription:@"readKnobs"];
    [provider readKnobs:^(WPSyncKnobs *knobs) {
        XCTAssertEqualObjects(knobs, [WPSyncKnobs defaultKnobs]);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:2];
}

@end
