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

- (void)testTryLockIsExclusiveAndReentrantAfterUnlock {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.exclusive"];
    NSUInteger t1 = [m tryLock];
    XCTAssertNotEqual(t1, 0u);            // acquired -> non-zero token
    XCTAssertEqual([m tryLock], 0u);      // already held
    XCTAssertTrue([m unlock:t1]);          // released
    NSUInteger t2 = [m tryLock];
    XCTAssertNotEqual(t2, 0u);            // free again
    XCTAssertNotEqual(t2, t1);            // a fresh token
    XCTAssertTrue([m unlock:t2]);
}

- (void)testNamedInstancesAreSharedPerName {
    XCTAssertTrue([WPSyncMutex mutexNamed:@"test.shared"] == [WPSyncMutex mutexNamed:@"test.shared"]);
    XCTAssertFalse([WPSyncMutex mutexNamed:@"test.shared"] == [WPSyncMutex mutexNamed:@"test.other"]);
}

- (void)testDifferentNamesAreIndependent {
    WPSyncMutex *a = [WPSyncMutex mutexNamed:@"test.indep.a"];
    WPSyncMutex *b = [WPSyncMutex mutexNamed:@"test.indep.b"];
    NSUInteger ta = [a tryLock];
    NSUInteger tb = [b tryLock];   // holding a does not block b
    XCTAssertNotEqual(ta, 0u);
    XCTAssertNotEqual(tb, 0u);
    [a unlock:ta];
    [b unlock:tb];
}

- (void)testUnlockFromAnotherThread {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.crossthread"];
    NSUInteger t = [m tryLock];
    XCTAssertNotEqual(t, 0u);
    XCTestExpectation *exp = [self expectationWithDescription:@"unlocked off-thread"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        XCTAssertTrue([m unlock:t]);   // unlock on a different thread than tryLock
        [exp fulfill];
    });
    [self waitForExpectations:@[exp] timeout:2];
    NSUInteger t2 = [m tryLock];
    XCTAssertNotEqual(t2, 0u);          // released successfully -> acquirable again
    [m unlock:t2];
}

- (void)testStaleUnlockDoesNotReleaseNewHolder {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.stale"];
    NSUInteger t1 = [m tryLock];        // A acquires
    XCTAssertTrue([m unlock:t1]);        // A releases
    NSUInteger t2 = [m tryLock];        // B acquires
    XCTAssertNotEqual(t2, 0u);
    XCTAssertFalse([m unlock:t1]);       // A's late/duplicate unlock must NOT release B's lock
    XCTAssertEqual([m tryLock], 0u);     // still held by B
    XCTAssertTrue([m unlock:t2]);         // B releases for real
    XCTAssertFalse([m unlock:t2]);        // duplicate unlock is a no-op
}

@end
