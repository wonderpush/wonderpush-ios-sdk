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
    XCTAssertTrue([m tryLock]);    // first acquire
    XCTAssertFalse([m tryLock]);   // already held
    XCTAssertFalse([m tryLock]);   // still held
    [m unlock];
    XCTAssertTrue([m tryLock]);     // free again
    [m unlock];
}

- (void)testNamedInstancesAreSharedPerName {
    XCTAssertTrue([WPSyncMutex mutexNamed:@"test.shared"] == [WPSyncMutex mutexNamed:@"test.shared"]);
    XCTAssertFalse([WPSyncMutex mutexNamed:@"test.shared"] == [WPSyncMutex mutexNamed:@"test.other"]);
}

- (void)testDifferentNamesAreIndependent {
    WPSyncMutex *a = [WPSyncMutex mutexNamed:@"test.indep.a"];
    WPSyncMutex *b = [WPSyncMutex mutexNamed:@"test.indep.b"];
    XCTAssertTrue([a tryLock]);
    XCTAssertTrue([b tryLock]);   // holding a does not block b
    [a unlock];
    [b unlock];
}

- (void)testUnlockFromAnotherThread {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"test.crossthread"];
    XCTAssertTrue([m tryLock]);
    XCTestExpectation *exp = [self expectationWithDescription:@"unlocked off-thread"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [m unlock];               // unlock on a different thread than tryLock
        [exp fulfill];
    });
    [self waitForExpectations:@[exp] timeout:2];
    XCTAssertTrue([m tryLock]);    // released successfully -> acquirable again
    [m unlock];
}

@end
