//
//  WPSyncTypesTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for the sdk-sync core types (issue wonderpush-ios-sdk-i2x.5):
// WPSyncSourceState, WPSyncKnobs, WPSyncResponseBlock, WPSyncDecision / WPSyncFetchHint.
// These pin the JS-reference semantics (zeros/nulls, JSON round-trip, presence distinctions)
// that the conformance harness (issue .11) later exercises against the shared vectors.

#import <XCTest/XCTest.h>
#import "WPSyncSourceState.h"
#import "WPSyncKnobs.h"
#import "WPSyncResponseBlock.h"
#import "WPSyncDecision.h"

@interface WPSyncTypesTests : XCTestCase
@end

@implementation WPSyncTypesTests

#pragma mark - WPSyncSourceState

- (void)testEmptyStateMatchesJSZerosAndNulls {
    WPSyncSourceState *e = [WPSyncSourceState emptyState];
    XCTAssertEqual(e.lastSyncDate, 0LL);
    XCTAssertNil(e.lastSyncMeta);
    XCTAssertEqual(e.lastVersion, 0LL);
    XCTAssertNil(e.lastVersionId);
    XCTAssertEqual(e.lastReadDate, 0LL);
    XCTAssertEqual(e.lastFetchAttemptedDate, 0LL);
    XCTAssertEqual(e.lastFetchUnsuccessfulAttemptCount, 0);
    XCTAssertNil(e.data);
}

- (void)testEmptyStateSerializesAllKeysWithNullForNullables {
    NSDictionary *d = [[WPSyncSourceState emptyState] toDictionary];
    XCTAssertEqual(d.count, (NSUInteger)8);
    XCTAssertEqualObjects(d[@"lastSyncMeta"], [NSNull null]);
    XCTAssertEqualObjects(d[@"lastVersionId"], [NSNull null]);
    XCTAssertEqualObjects(d[@"data"], [NSNull null]);
}

- (void)testSourceStateRoundTripAndEquality {
    NSDictionary *in = @{
        @"lastSyncDate": @5000, @"lastSyncMeta": @{@"m": @1},
        @"lastVersion": @100, @"lastVersionId": @"v100", @"lastReadDate": @1000,
        @"lastFetchAttemptedDate": @0, @"lastFetchUnsuccessfulAttemptCount": @0,
        @"data": @{@"firstName": @"Alice"},
    };
    WPSyncSourceState *s = [WPSyncSourceState stateWithDictionary:in];
    XCTAssertEqual(s.lastVersion, 100LL);
    XCTAssertEqualObjects(s.lastVersionId, @"v100");
    XCTAssertEqualObjects([s toDictionary], in);
    XCTAssertEqualObjects(s, [WPSyncSourceState stateWithDictionary:in]);
}

- (void)testSourceStateCopyIsIndependent {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastVersion = 100;
    WPSyncSourceState *c = [s copy];
    c.lastVersion = 101;
    XCTAssertEqual(s.lastVersion, 100LL);
    XCTAssertEqual(c.lastVersion, 101LL);
    XCTAssertNotEqualObjects(s, c);
}

- (void)testSourceStateNumericVersionId {
    WPSyncSourceState *s = [WPSyncSourceState stateWithDictionary:@{@"lastVersionId": @42}];
    XCTAssertEqualObjects(s.lastVersionId, @42);
    XCTAssertEqualObjects([s toDictionary][@"lastVersionId"], @42);
}

#pragma mark - WPSyncKnobs

- (void)testKnobsRoundTripPreservesInfinityAndBool {
    NSDictionary *kd = @{
        @"weakSyncSignalDebounceMs": @5000, @"maxLastSyncDateAgeMs": @(INFINITY),
        @"maxLastReadDateAgeMs": @(INFINITY), @"maxPopupsEntries": @1000, @"maxInboxEntries": @1000,
        @"exponentialBackoffMinMs": @1000, @"exponentialBackoffMaxMs": @300000,
        @"exponentialBackoffRatio": @2, @"exponentialBackoffJitterRatio": @0.5,
        @"mutexTtlMs": @600000, @"opportunisticInjectionEnabled": @YES, @"minSourceFetchIntervalMs": @2000,
    };
    WPSyncKnobs *k = [WPSyncKnobs knobsWithDictionary:kd];
    XCTAssertTrue(isinf(k.maxLastSyncDateAgeMs));
    XCTAssertTrue(isinf(k.maxLastReadDateAgeMs));
    XCTAssertTrue(k.opportunisticInjectionEnabled);
    XCTAssertEqual(k.maxPopupsEntries, 1000);
    XCTAssertEqualObjects(k, [WPSyncKnobs knobsWithDictionary:kd]);
}

#pragma mark - WPSyncResponseBlock

- (void)testBlockMissingVsEmptyVsPopulated {
    XCTAssertNil([WPSyncResponseBlock blockWithDictionary:nil]);

    WPSyncResponseBlock *empty = [WPSyncResponseBlock blockWithDictionary:@{}];
    XCTAssertNotNil(empty);
    XCTAssertTrue(empty.isEmpty);

    WPSyncResponseBlock *b = [WPSyncResponseBlock blockWithDictionary:@{
        @"version": @101, @"versionId": @"v101", @"data": @{@"x": @1}, @"meta": @{@"k": @2},
    }];
    XCTAssertFalse(b.isEmpty);
    XCTAssertEqualObjects(b.version, @101);
    XCTAssertTrue(b.hasVersionId);
    XCTAssertEqualObjects(b.versionId, @"v101");
    XCTAssertTrue(b.hasData);
    XCTAssertEqualObjects(b.data, (@{@"x": @1}));
    XCTAssertEqualObjects(b.meta, (@{@"k": @2}));
    XCTAssertNil(b.knownReadDate);
    XCTAssertFalse(b.hasDelta);
}

- (void)testBlockDistinguishesExplicitNullFromAbsent {
    WPSyncResponseBlock *withNull = [WPSyncResponseBlock blockWithDictionary:@{@"versionId": [NSNull null]}];
    XCTAssertTrue(withNull.hasVersionId);
    XCTAssertEqualObjects(withNull.versionId, [NSNull null]);

    WPSyncResponseBlock *without = [WPSyncResponseBlock blockWithDictionary:@{@"version": @1}];
    XCTAssertFalse(without.hasVersionId);
    XCTAssertNil(without.versionId);
}

#pragma mark - WPSyncDecision / WPSyncFetchHint

- (void)testEmptyDecisionSerializesToEmptyDictionary {
    XCTAssertEqualObjects([[WPSyncDecision new] toDictionary], @{});
}

- (void)testWeakFetchDecision {
    WPSyncDecision *d = [WPSyncDecision new];
    d.triggerFetch = @"weak";
    XCTAssertEqualObjects([d toDictionary], @{@"triggerFetch": @"weak"});
}

- (void)testRichDecisionOmitsUnsetAndIncludesNextStateApplyDataAndHint {
    WPSyncSourceState *s = [WPSyncSourceState stateWithDictionary:@{@"lastVersion": @100}];
    WPSyncDecision *d = [WPSyncDecision new];
    d.nextState = s;
    d.hasApplyData = YES;
    d.applyData = @{@"firstName": @"Alice"};
    WPSyncFetchHint *h = [WPSyncFetchHint new];
    h.knownVersion = @200;
    d.fetchHint = h;

    NSDictionary *dd = [d toDictionary];
    XCTAssertNotNil(dd[@"newState"]);                                  // serialized under JSON key "newState"
    XCTAssertEqualObjects(dd[@"newState"][@"lastVersion"], @100);
    XCTAssertEqualObjects(dd[@"applyData"], (@{@"firstName": @"Alice"}));
    XCTAssertEqualObjects(dd[@"fetchHint"], (@{@"knownVersion": @200}));
    XCTAssertNil(dd[@"applyDelta"]);                                   // unset -> omitted
    XCTAssertNil(dd[@"clearState"]);
}

- (void)testApplyDataExplicitNullStillSerializesViaPresenceFlag {
    WPSyncDecision *d = [WPSyncDecision new];
    d.hasApplyData = YES;
    d.applyData = nil;   // the "no data exists" reset: present but null
    XCTAssertEqualObjects([d toDictionary][@"applyData"], [NSNull null]);
}

@end
