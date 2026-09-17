//
//  WPSyncKnobsTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncKnobs logic (issue wonderpush-ios-sdk-i2x.7): defaultKnobs, mergeKnobs and
// isStateStale. Cases mirror merge-knobs.vectors.json (6) and is-state-stale.vectors.json (4); the
// full vector-driven run lands in the conformance harness (issue .11).

#import <XCTest/XCTest.h>
#import "WPSyncKnobs.h"
#import "WPSyncSourceState.h"

@interface WPSyncKnobsTests : XCTestCase
@end

@implementation WPSyncKnobsTests

#pragma mark - defaultKnobs

- (void)testDefaultKnobsMatchCanonicalValues {
    WPSyncKnobs *k = [WPSyncKnobs defaultKnobs];
    XCTAssertEqual(k.weakSyncSignalDebounceMs, 5000.0);
    XCTAssertTrue(isinf(k.maxLastSyncDateAgeMs));
    XCTAssertTrue(isinf(k.maxLastReadDateAgeMs));
    XCTAssertEqual(k.maxPopupsEntries, 1000);
    XCTAssertEqual(k.maxInboxEntries, 1000);
    XCTAssertEqual(k.exponentialBackoffMinMs, 1000.0);
    XCTAssertEqual(k.exponentialBackoffMaxMs, 300000.0);
    XCTAssertEqual(k.exponentialBackoffRatio, 2.0);
    XCTAssertEqual(k.exponentialBackoffJitterRatio, 0.5);
    XCTAssertEqual(k.mutexTtlMs, 600000.0);
    XCTAssertTrue(k.opportunisticInjectionEnabled);
    XCTAssertEqual(k.minSourceFetchIntervalMs, 2000.0);
}

#pragma mark - mergeKnobs

- (WPSyncKnobs *)merge:(NSDictionary *)data {
    return [WPSyncKnobs mergeKnobsFromDefaults:[WPSyncKnobs defaultKnobs] remoteConfig:data];
}

- (void)testMergeNullAndEmptyYieldDefaults {
    XCTAssertEqualObjects([self merge:nil], [WPSyncKnobs defaultKnobs]);
    XCTAssertEqualObjects([self merge:@{}], [WPSyncKnobs defaultKnobs]);
}

- (void)testMergeOverridesSeveral {
    WPSyncKnobs *k = [self merge:@{
        @"syncWeakSignalDebounceMs": @1234,
        @"syncMutexTtlMs": @30000,
        @"syncMinSourceFetchIntervalMs": @500,
    }];
    XCTAssertEqual(k.weakSyncSignalDebounceMs, 1234.0);
    XCTAssertEqual(k.mutexTtlMs, 30000.0);
    XCTAssertEqual(k.minSourceFetchIntervalMs, 500.0);
    // untouched fields keep defaults
    XCTAssertTrue(isinf(k.maxLastSyncDateAgeMs));
    XCTAssertEqual(k.exponentialBackoffMaxMs, 300000.0);
    XCTAssertTrue(k.opportunisticInjectionEnabled);
}

- (void)testMergeKillSwitchOnlyExplicitBooleanFalseDisables {
    XCTAssertFalse([self merge:@{@"syncOpportunisticInjection": @NO}].opportunisticInjectionEnabled);
    // anything other than boolean false keeps it on
    XCTAssertTrue([self merge:@{@"syncOpportunisticInjection": @YES}].opportunisticInjectionEnabled);
    XCTAssertTrue([self merge:@{@"syncOpportunisticInjection": @0}].opportunisticInjectionEnabled);   // numeric 0 != false
    XCTAssertTrue([self merge:@{}].opportunisticInjectionEnabled);
}

- (void)testMergeNonNumberIgnored {
    WPSyncKnobs *k = [self merge:@{@"syncWeakSignalDebounceMs": @"nope"}];
    XCTAssertEqual(k.weakSyncSignalDebounceMs, 5000.0);   // falls back to default
}

- (void)testMergeMaxAgeFiniteOverride {
    WPSyncKnobs *k = [self merge:@{@"syncMaxLastReadDateAgeMs": @5000}];
    XCTAssertEqual(k.maxLastReadDateAgeMs, 5000.0);
    XCTAssertTrue(isinf(k.maxLastSyncDateAgeMs));   // the other cap stays infinite
}

#pragma mark - isStateStale

- (WPSyncSourceState *)stateLastSync:(long long)sync lastRead:(long long)read {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastSyncDate = sync;
    s.lastReadDate = read;
    return s;
}

- (void)testStaleInfiniteCapsNeverStale {
    WPSyncKnobs *k = [WPSyncKnobs defaultKnobs];   // both caps Infinity
    XCTAssertFalse([WPSyncKnobs isStateStale:[self stateLastSync:1 lastRead:1] knobs:k now:999999999]);
}

- (void)testStaleFiniteReadDateCapOldIsStale {
    WPSyncKnobs *k = [self merge:@{@"syncMaxLastReadDateAgeMs": @5000}];
    XCTAssertTrue([WPSyncKnobs isStateStale:[self stateLastSync:1 lastRead:1] knobs:k now:999999999]);
}

- (void)testStaleFiniteReadDateCapFreshNotStale {
    WPSyncKnobs *k = [self merge:@{@"syncMaxLastReadDateAgeMs": @5000}];
    XCTAssertFalse([WPSyncKnobs isStateStale:[self stateLastSync:1 lastRead:999996000] knobs:k now:999999999]);
}

- (void)testStaleNeverReadZeroNotStaleEvenWithFiniteCap {
    WPSyncKnobs *k = [self merge:@{@"syncMaxLastReadDateAgeMs": @5000}];
    XCTAssertFalse([WPSyncKnobs isStateStale:[self stateLastSync:0 lastRead:0] knobs:k now:999999999]);
}

@end
