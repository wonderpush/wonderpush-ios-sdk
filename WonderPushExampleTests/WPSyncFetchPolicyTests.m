//
//  WPSyncFetchPolicyTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncFetchPolicy (issue wonderpush-ios-sdk-i2x.8): debounce, rate-limit and
// backoff math (cases mirror the should-debounce-weak-signal / should-rate-limit-source /
// compute-backoff-sleep vectors), plus the explicit-fetch param builder (not vector-covered; an
// integration concern, tested directly here). Full vector run lands in the harness (issue .11).

#import <XCTest/XCTest.h>
#import "WPSyncFetchPolicy.h"
#import "WPSyncKnobs.h"
#import "WPSyncSourceState.h"
#import "WPSyncDecision.h"

@interface WPSyncFetchPolicyTests : XCTestCase
@end

@implementation WPSyncFetchPolicyTests

#pragma mark - shouldDebounceWeakSignal

- (void)testWeakSignalDebounce {
    // never fetched -> never debounced
    XCTAssertFalse([WPSyncFetchPolicy shouldDebounceWeakSignalAtNow:10000 lastFetchAttemptedDate:0 debounceMs:5000]);
    // inside window -> debounce
    XCTAssertTrue([WPSyncFetchPolicy shouldDebounceWeakSignalAtNow:10000 lastFetchAttemptedDate:8000 debounceMs:5000]);
    // exactly at window edge -> not debounced (strict <)
    XCTAssertFalse([WPSyncFetchPolicy shouldDebounceWeakSignalAtNow:10000 lastFetchAttemptedDate:5000 debounceMs:5000]);
    // outside window -> not debounced
    XCTAssertFalse([WPSyncFetchPolicy shouldDebounceWeakSignalAtNow:10000 lastFetchAttemptedDate:4000 debounceMs:5000]);
}

#pragma mark - shouldRateLimitSource

- (void)testRateLimit {
    XCTAssertFalse([WPSyncFetchPolicy shouldRateLimitSourceAtNow:10000 lastFetchAttemptedDate:0 minIntervalMs:2000]);
    XCTAssertTrue([WPSyncFetchPolicy shouldRateLimitSourceAtNow:10000 lastFetchAttemptedDate:9000 minIntervalMs:2000]);
    XCTAssertFalse([WPSyncFetchPolicy shouldRateLimitSourceAtNow:10000 lastFetchAttemptedDate:8000 minIntervalMs:2000]); // edge
    // disabled when minInterval <= 0
    XCTAssertFalse([WPSyncFetchPolicy shouldRateLimitSourceAtNow:10000 lastFetchAttemptedDate:9999 minIntervalMs:0]);
}

#pragma mark - computeBackoffSleep

- (WPSyncKnobs *)backoffKnobs {
    return [WPSyncKnobs knobsWithDictionary:@{
        @"exponentialBackoffMinMs": @1000, @"exponentialBackoffMaxMs": @300000,
        @"exponentialBackoffRatio": @2, @"exponentialBackoffJitterRatio": @0.5,
    }];
}

- (void)testBackoff {
    WPSyncKnobs *k = [self backoffKnobs];
    double eps = 1e-6;
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:0 rand:0.5 knobs:k], 0, eps);
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:-3 rand:0.5 knobs:k], 0, eps);
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:1 rand:0 knobs:k], 2000, eps);
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:3 rand:0 knobs:k], 8000, eps);
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:1 rand:1 knobs:k], 3000, eps);
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:50 rand:0 knobs:k], 300000, eps);
    XCTAssertEqualWithAccuracy([WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:50 rand:1 knobs:k], 450000, eps);
}

#pragma mark - buildExplicitFetchParams

- (void)testExplicitParamsBaseStateAndIdentifiers {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastSyncDate = 111; s.lastVersion = 222; s.lastReadDate = 333;
    NSDictionary *p = [WPSyncFetchPolicy buildExplicitFetchParamsWithIdentifiers:@{
        @"deviceId": @"D1", @"installationId": @"I1", @"visitorId": @"", // empty visitorId dropped
    } state:s hint:nil];
    XCTAssertEqualObjects(p[@"deviceId"], @"D1");
    XCTAssertEqualObjects(p[@"installationId"], @"I1");
    XCTAssertNil(p[@"visitorId"]);                 // empty string is falsy
    XCTAssertNil(p[@"userId"]);                    // never added here
    XCTAssertEqualObjects(p[@"lastSyncDate"], @111);
    XCTAssertEqualObjects(p[@"lastVersion"], @222);
    XCTAssertEqualObjects(p[@"lastReadDate"], @333);
    XCTAssertNil(p[@"lastSyncMeta"]);              // nil meta omitted
    XCTAssertNil(p[@"lastVersionId"]);             // nil omitted
}

- (void)testExplicitParamsMetaJSONAndVersionIdAndHint {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastSyncMeta = @{@"syncVersion": @0};
    s.lastVersionId = @"v9";
    WPSyncFetchHint *h = [WPSyncFetchHint new];
    h.knownVersion = @500;
    h.knownVersionId = [NSNull null];              // null -> skipped
    h.knownReadDate = @600;
    NSDictionary *p = [WPSyncFetchPolicy buildExplicitFetchParamsWithIdentifiers:@{} state:s hint:h];

    XCTAssertEqualObjects(p[@"lastVersionId"], @"v9");
    // lastSyncMeta is a JSON string; parse it back
    id meta = [NSJSONSerialization JSONObjectWithData:[p[@"lastSyncMeta"] dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0 error:nil];
    XCTAssertEqualObjects(meta, (@{@"syncVersion": @0}));
    XCTAssertEqualObjects(p[@"knownVersion"], @500);
    XCTAssertEqualObjects(p[@"knownReadDate"], @600);
    XCTAssertNil(p[@"knownVersionId"]);            // NSNull skipped
}

- (void)testExplicitPathForSource {
    XCTAssertEqualObjects(WPSyncExplicitPathForSource(@"contact"), @"/contact");
    XCTAssertEqualObjects(WPSyncExplicitPathForSource(@"inbox"), @"/inbox");
    XCTAssertNil(WPSyncExplicitPathForSource(@"nope"));
}

@end
