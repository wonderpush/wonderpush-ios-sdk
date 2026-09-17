//
//  WPSyncPopupsStoreTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-popups-store.test.ts (issue .23):
// multi-object dedupe-by-id/highest-updateDate, expiry pruning, tombstone retention. Plus the
// WPSyncPopupsSource transformer wrapper.

#import <XCTest/XCTest.h>
#import "WPSyncPopupsStore.h"
#import "WPSyncPopupsSource.h"

static const long long NOW = 1000000;
static const long long kFuture = 1000000 + 100000;   // not yet expired
static const long long kPast = 1000000 - 1;          // expired

@interface WPSyncPopupsStoreTests : XCTestCase
@end

@implementation WPSyncPopupsStoreTests

// Build an item like the JS test helper: {id, updateDate, status:'active', expirationDate:future, ...extra}.
static NSDictionary *item(NSString *itemId, long long updateDate, NSDictionary *extra) {
    NSMutableDictionary *m = [@{@"id": itemId, @"updateDate": @(updateDate), @"status": @"active", @"expirationDate": @(kFuture)} mutableCopy];
    [m addEntriesFromDictionary:extra ?: @{}];
    return m;
}

- (NSArray<NSString *> *)ids:(NSArray<NSDictionary *> *)list {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *it in list) [out addObject:it[@"id"]];
    return out;
}

- (NSDictionary *)byId:(NSArray<NSDictionary *> *)list {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSDictionary *it in list) out[it[@"id"]] = it;
    return out;
}

#pragma mark - resetPopupsData (full reset)

- (void)testResetDedupesByIdHighestUpdateDateWins {
    NSArray *out = [WPSyncPopupsStore resetPopupsData:@[item(@"a", 1, nil), item(@"b", 5, nil), item(@"a", 9, nil)] now:NOW];
    XCTAssertEqualObjects([self ids:out], (@[@"a", @"b"]));
    XCTAssertEqualObjects([self byId:out][@"a"][@"updateDate"], @9);
    XCTAssertEqualObjects([self byId:out][@"b"][@"updateDate"], @5);
}

- (void)testResetPrunesExpiredItems {
    NSArray *out = [WPSyncPopupsStore resetPopupsData:@[item(@"a", 1, @{@"expirationDate": @(kPast)}), item(@"b", 2, nil)] now:NOW];
    XCTAssertEqualObjects([self ids:out], (@[@"b"]));
}

- (void)testResetTreatsNonArrayAsEmpty {
    XCTAssertEqualObjects([WPSyncPopupsStore resetPopupsData:nil now:NOW], @[]);
    XCTAssertEqualObjects([WPSyncPopupsStore resetPopupsData:@{} now:NOW], @[]);
}

#pragma mark - applyPopupsDelta (merge array of full objects by id)

- (void)testDeltaAddsNewAndUpdatesExistingWhenHigherUpdateDate {
    NSArray *current = @[item(@"a", 1, nil), item(@"b", 2, nil)];
    NSArray *out = [WPSyncPopupsStore applyPopupsDelta:current delta:@[item(@"a", 5, @{@"foo": @"bar"}), item(@"c", 3, nil)] now:NOW];
    NSDictionary *byId = [self byId:out];
    XCTAssertEqualObjects(byId[@"a"][@"updateDate"], @5);
    XCTAssertEqualObjects(byId[@"a"][@"foo"], @"bar");
    XCTAssertEqualObjects(byId[@"b"][@"updateDate"], @2);
    XCTAssertEqualObjects(byId[@"c"][@"updateDate"], @3);
}

- (void)testDeltaDoesNotReplaceWhenLowerUpdateDate {
    NSArray *current = @[item(@"a", 9, nil)];
    NSArray *out = [WPSyncPopupsStore applyPopupsDelta:current delta:@[item(@"a", 4, nil)] now:NOW];
    XCTAssertEqual(out.count, 1u);
    XCTAssertEqualObjects(out[0][@"updateDate"], @9);
}

- (void)testDeltaRetainsTombstoneSupersedingActive {
    NSArray *current = @[item(@"a", 1, nil)];
    NSArray *out = [WPSyncPopupsStore applyPopupsDelta:current delta:@[item(@"a", 7, @{@"status": @"deleted"})] now:NOW];
    XCTAssertEqual(out.count, 1u);
    XCTAssertEqualObjects(out[0][@"status"], @"deleted");
    XCTAssertEqualObjects(out[0][@"updateDate"], @7);
}

- (void)testDeltaPrunesTombstoneOnceExpired {
    NSArray *current = @[item(@"a", 1, nil)];
    NSArray *out = [WPSyncPopupsStore applyPopupsDelta:current delta:@[item(@"a", 7, @{@"status": @"deleted", @"expirationDate": @(kPast)})] now:NOW];
    XCTAssertEqualObjects(out, @[]);
}

- (void)testDeltaMergesOntoEmptyOrNonArrayBase {
    XCTAssertEqualObjects([self ids:[WPSyncPopupsStore applyPopupsDelta:nil delta:@[item(@"a", 1, nil)] now:NOW]], (@[@"a"]));
    XCTAssertEqualObjects([WPSyncPopupsStore applyPopupsDelta:@[] delta:@[] now:NOW], @[]);
}

- (void)testDeltaNonArrayIsNoOpMergeWithPruning {
    NSArray *current = @[item(@"a", 1, nil), item(@"b", 2, @{@"expirationDate": @(kPast)})];
    XCTAssertEqualObjects([self ids:[WPSyncPopupsStore applyPopupsDelta:current delta:nil now:NOW]], (@[@"a"]));
}

- (void)testMalformedEntriesSkipped {
    NSArray *out = [WPSyncPopupsStore resetPopupsData:@[@"nope", @{@"noId": @1}, item(@"a", 1, nil)] now:NOW];
    XCTAssertEqualObjects([self ids:out], (@[@"a"]));
}

#pragma mark - clearPopups

- (void)testClearReturnsEmpty {
    XCTAssertEqualObjects([WPSyncPopupsStore clearPopups], @[]);
}

#pragma mark - WPSyncPopupsSource transformer

- (void)testSourceApplyDataUsesInjectedClock {
    WPSyncPopupsSource *src = [[WPSyncPopupsSource alloc] initWithNowProvider:^long long{ return NOW; }];
    NSArray *out = [src dataByApplyingData:@[item(@"a", 1, @{@"expirationDate": @(kPast)}), item(@"b", 2, nil)] toCurrentData:nil];
    XCTAssertEqualObjects([self ids:out], (@[@"b"]));   // expired 'a' pruned at injected now
}

- (void)testSourceApplyDeltaMergesIntoCurrent {
    WPSyncPopupsSource *src = [[WPSyncPopupsSource alloc] initWithNowProvider:^long long{ return NOW; }];
    NSArray *current = @[item(@"a", 1, nil)];
    NSArray *out = [src dataByApplyingDelta:@[item(@"a", 5, nil), item(@"c", 3, nil)] toCurrentData:current];
    XCTAssertEqualObjects([self byId:out][@"a"][@"updateDate"], @5);
    XCTAssertEqualObjects([self byId:out][@"c"][@"updateDate"], @3);
}

@end
