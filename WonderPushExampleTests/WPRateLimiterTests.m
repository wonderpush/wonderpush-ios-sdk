//
//  WPRateLimiterTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 13/07/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPRateLimiter.h"

@interface WPRateLimiterTests : XCTestCase

@end

@implementation WPRateLimiterTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSimple {
    WPRateLimit *limit = [[WPRateLimit alloc] initWithKey:@"testLimit" timeToLive:1 limit:5];
    WPRateLimiter *limiter = [WPRateLimiter rateLimiter];
    [limiter clear:limit];

    [limiter increment:limit]; // 4 left
    XCTAssert(![limiter isRateLimited:limit]);
    [self waitFor:0.1]; // 0.9s left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 3 left
    XCTAssert(![limiter isRateLimited:limit]);
    [self waitFor:0.1]; // 0.8s left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 2 left
    XCTAssert(![limiter isRateLimited:limit]);
    [self waitFor:0.1]; // 0.7s left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 1 left
    XCTAssert(![limiter isRateLimited:limit]);
    [self waitFor:0.1]; // 0.6s left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 0 left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited!
    [self waitFor:0.1]; // 0.5s left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited!
    [self waitFor:0.1]; // 0.4s left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited!
    [self waitFor:0.1]; // 0.3s left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited!
    [self waitFor:0.1]; // 0.2s left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited!
    [self waitFor:0.1]; // 0.1s left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited!
    [self waitFor:0.1]; // 0s left
    XCTAssert(![limiter isRateLimited:limit]);
}

- (void)testFloatingWindow {
    WPRateLimit *limit = [[WPRateLimit alloc] initWithKey:@"testLimit" timeToLive:1 limit:5];
    WPRateLimiter *limiter = [WPRateLimiter rateLimiter];
    [limiter clear:limit];

    [limiter increment:limit]; // 4 left
    XCTAssert(![limiter isRateLimited:limit]);

    [self waitFor:0.8];

    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 3 left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 2 left

    [self waitFor:0.1];

    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 1 left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 0 left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited

    [self waitFor:0.1];

    // 1 left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 0 left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited

    [self waitFor:0.7];

    XCTAssert([limiter isRateLimited:limit]); // Rate limited

    [self waitFor:0.1];

    // 2 left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 1 left
    XCTAssert(![limiter isRateLimited:limit]);
    [limiter increment:limit]; // 0 left
    XCTAssert([limiter isRateLimited:limit]); // Rate limited
}

- (void)testStorage {
    WPRateLimiter *limiter1 = [WPRateLimiter new];
    WPRateLimit *limit = [[WPRateLimit alloc] initWithKey:@"testLimit" timeToLive:0.5 limit:1];
    [limiter1 clear:limit];
    [limiter1 increment:limit];
    WPRateLimiter *limiter2 = [WPRateLimiter new];
    XCTAssert([limiter2 isRateLimited:limit]);
    [self waitFor:0.5];
    XCTAssert(![limiter2 isRateLimited:limit]);
 }

- (void)waitFor:(NSTimeInterval)timeToWait {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeToWait * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}
@end
