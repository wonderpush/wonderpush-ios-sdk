//
//  WPSyncMutexTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncMutex (issue wonderpush-ios-sdk-i2x.17). Each test uses a unique name since
// mutexes are process-wide singletons keyed by name.

#import <XCTest/XCTest.h>
#import "WPSyncMutex.h"

@interface WPSyncMutexTests : XCTestCase
@end

@implementation WPSyncMutexTests

static const double kTTL = 600000;   // large TTL: no reclaim in these tests

- (void)testTryLockIsExclusiveAndReentrantAfterUnlock {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.exclusive"];
    NSUInteger t1 = [m tryLockAtTime:1000 ttlMs:kTTL];
    XCTAssertNotEqual(t1, 0u);                              // acquired -> non-zero token
    XCTAssertEqual([m tryLockAtTime:1000 ttlMs:kTTL], 0u); // already held, not expired
    XCTAssertTrue([m unlock:t1]);                           // released
    NSUInteger t2 = [m tryLockAtTime:1000 ttlMs:kTTL];
    XCTAssertNotEqual(t2, 0u);                              // free again
    XCTAssertNotEqual(t2, t1);                              // a fresh token
    XCTAssertTrue([m unlock:t2]);
}

- (void)testNamedInstancesAreSharedPerName {
    XCTAssertTrue([WPSyncMutex mutexNamed:@"test.shared"] == [WPSyncMutex mutexNamed:@"test.shared"]);
    XCTAssertFalse([WPSyncMutex mutexNamed:@"test.shared"] == [WPSyncMutex mutexNamed:@"test.other"]);
}

- (void)testDifferentNamesAreIndependent {
    WPSyncMutex *a = [WPSyncMutex mutexNamed:@"test.indep.a"];
    WPSyncMutex *b = [WPSyncMutex mutexNamed:@"test.indep.b"];
    NSUInteger ta = [a tryLockAtTime:1000 ttlMs:kTTL];
    NSUInteger tb = [b tryLockAtTime:1000 ttlMs:kTTL];   // holding a does not block b
    XCTAssertNotEqual(ta, 0u);
    XCTAssertNotEqual(tb, 0u);
    [a unlock:ta];
    [b unlock:tb];
}

- (void)testUnlockFromAnotherThread {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.crossthread"];
    NSUInteger t = [m tryLockAtTime:1000 ttlMs:kTTL];
    XCTAssertNotEqual(t, 0u);
    XCTestExpectation *exp = [self expectationWithDescription:@"unlocked off-thread"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        XCTAssertTrue([m unlock:t]);   // unlock on a different thread than tryLock
        [exp fulfill];
    });
    [self waitForExpectations:@[exp] timeout:2];
    NSUInteger t2 = [m tryLockAtTime:1000 ttlMs:kTTL];
    XCTAssertNotEqual(t2, 0u);          // released successfully -> acquirable again
    [m unlock:t2];
}

- (void)testStaleUnlockDoesNotReleaseNewHolder {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.stale"];
    NSUInteger t1 = [m tryLockAtTime:1000 ttlMs:kTTL];        // A acquires
    XCTAssertTrue([m unlock:t1]);                             // A releases
    NSUInteger t2 = [m tryLockAtTime:1000 ttlMs:kTTL];        // B acquires
    XCTAssertNotEqual(t2, 0u);
    XCTAssertFalse([m unlock:t1]);                            // A's late/duplicate unlock must NOT release B
    XCTAssertEqual([m tryLockAtTime:1000 ttlMs:kTTL], 0u);    // still held by B
    XCTAssertTrue([m unlock:t2]);                             // B releases for real
    XCTAssertFalse([m unlock:t2]);                            // duplicate unlock is a no-op
}

- (void)testTTLReclaimAfterExpiry {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.ttl"];
    NSUInteger t1 = [m tryLockAtTime:1000 ttlMs:5000];
    XCTAssertNotEqual(t1, 0u);
    XCTAssertEqual([m tryLockAtTime:5000 ttlMs:5000], 0u);    // 5000-1000=4000 < 5000 -> still held
    NSUInteger t2 = [m tryLockAtTime:6001 ttlMs:5000];        // 6001-1000=5001 >= 5000 -> reclaimable
    XCTAssertNotEqual(t2, 0u);
    XCTAssertNotEqual(t2, t1);
    XCTAssertFalse([m unlock:t1]);                            // the wedged holder's late unlock is a no-op
    XCTAssertEqual([m tryLockAtTime:6001 ttlMs:5000], 0u);    // now held by the reclaimer
    XCTAssertTrue([m unlock:t2]);
}

- (void)testTTLDisabledNeverReclaims {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.ttl.off"];
    NSUInteger t = [m tryLockAtTime:0 ttlMs:0];               // ttl<=0 disables reclaim
    XCTAssertNotEqual(t, 0u);
    XCTAssertEqual([m tryLockAtTime:999999999 ttlMs:0], 0u);  // never expires
    XCTAssertTrue([m unlock:t]);
}

@end
