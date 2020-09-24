//
//  WPPresenceManagerTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 24/09/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPPresenceManager.h"

@interface MockPresenceDelegate : NSObject<WPPresenceManagerAutoRenewDelegate>
@property (nonatomic, nullable, strong) WPPresencePayload *presenceToRenew;
@end

@implementation MockPresenceDelegate
- (void)presenceManager:(WPPresenceManager *)presenceManager wantsToRenewPresence:(WPPresencePayload *)presence {
    self.presenceToRenew = presence;
}
@end

@interface WPPresenceManagerTests : XCTestCase
@end


@implementation WPPresenceManagerTests

- (void)setUp {

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/**
 Ensures the payload's elapsedTime is properly computed
 */
- (void)testPresencePayloadElapsedTime {
    NSDate *fromDate = [NSDate date];
    WPPresencePayload *payload = [[WPPresencePayload alloc] initWithFromDate:fromDate untilDate:[fromDate dateByAddingTimeInterval:10]];
    XCTAssertEqual(payload.elapsedTime, 10);
    
    payload = [[WPPresencePayload alloc] initWithFromDate:fromDate untilDate:[fromDate dateByAddingTimeInterval:-10]];
    XCTAssertEqual(payload.elapsedTime, -10);
}

/**
 Ensures the presence payload serializes correctly
 */
- (void)testPresencePayloadSerialization {
    NSDate *fromDate = [NSDate date];
    NSDate *untilDate = [fromDate dateByAddingTimeInterval:10];
    WPPresencePayload *payload = [[WPPresencePayload alloc] initWithFromDate:fromDate untilDate:untilDate];

    id serialized = payload.toJSON;
    
    // It should be an NSDictionary
    XCTAssertTrue([serialized isKindOfClass:NSDictionary.class]);
    
    // Dates should be epoch milliseconds
    XCTAssertEqual((long)(fromDate.timeIntervalSince1970 * 1000), [serialized[@"fromDate"] longValue]);
    XCTAssertEqual((long)(untilDate.timeIntervalSince1970 * 1000), [serialized[@"untilDate"] longValue]);
    
    // Elapsed time in milliseconds
    XCTAssertEqual(10000, [serialized[@"elapsedTime"] longValue]);
}

/**
 Checks the presence payload when the presence just started
 */
- (void) testPresenceDidStart {
    NSDate *now = [NSDate date];
    WPPresenceManager *manager = [[WPPresenceManager alloc] initWithAutoRenewDelegate:nil anticipatedTime:10 safetyMarginTime:0];
    WPPresencePayload *payload = [manager presenceDidStart];
    XCTAssertEqual(10, payload.elapsedTime);
    XCTAssertEqualWithAccuracy(now.timeIntervalSince1970, payload.fromDate.timeIntervalSince1970, 0.1);
}

/**
 Check the presence payload when presence ends without having started
 */
- (void) testPresenceDidStopNoStart {
    WPPresenceManager *manager = [[WPPresenceManager alloc] initWithAutoRenewDelegate:nil anticipatedTime:10 safetyMarginTime:0];
    NSDate *now = [NSDate date];
    WPPresencePayload *payload = [manager presenceWillStop];
    XCTAssertEqualWithAccuracy(now.timeIntervalSince1970, payload.fromDate.timeIntervalSince1970, 0.1);
    XCTAssertEqualWithAccuracy(now.timeIntervalSince1970, payload.untilDate.timeIntervalSince1970, 0.1);
}

/**
 Check the presence payload when presence ends
 */
- (void) testPresenceDidStop {
    WPPresenceManager *manager = [[WPPresenceManager alloc] initWithAutoRenewDelegate:nil anticipatedTime:10 safetyMarginTime:0];

    // Note: there shouldn't be a need to call presenceDidStart
    NSDate *startDate = [NSDate date];
    [manager presenceDidStart];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    // 100 ms later...
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDate *stopDate = [NSDate date];
        WPPresencePayload *stopPayload = [manager presenceWillStop];
        
        XCTAssertEqualWithAccuracy(startDate.timeIntervalSince1970, stopPayload.fromDate.timeIntervalSince1970, 0.01);
        XCTAssertEqualWithAccuracy(stopDate.timeIntervalSince1970, stopPayload.untilDate.timeIntervalSince1970, 0.01);
        [expectation fulfill];
    });

    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}

- (void) testAutoRenew {
    MockPresenceDelegate *delegate = [MockPresenceDelegate new];
    WPPresenceManager *manager = [[WPPresenceManager alloc]
                                  initWithAutoRenewDelegate:delegate
                                  anticipatedTime:0.5
                                  safetyMarginTime:0.1];

    NSDate *startDate = [NSDate date];
    [manager presenceDidStart];
    XCTAssertNil(delegate.presenceToRenew);
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    
    // Wait 350ms (no auto-renew).
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        // no auto-renew should have been attempted
        XCTAssertNil(delegate.presenceToRenew);
    });
    
    // Wait 410ms (auto-renew attempted at 0.5 - 0.1 = 400ms.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.41 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Auto-renew should have been attempted
        WPPresencePayload *autoRenewPayload = delegate.presenceToRenew;
        XCTAssertNotNil(autoRenewPayload);
        XCTAssertEqualWithAccuracy(startDate.timeIntervalSince1970, autoRenewPayload.fromDate.timeIntervalSince1970, 0.01);
        NSDate *expectedUntilDate = [startDate dateByAddingTimeInterval:0.4 + 0.5];
        XCTAssertEqualWithAccuracy(expectedUntilDate.timeIntervalSince1970, autoRenewPayload.untilDate.timeIntervalSince1970, 0.01);
        
        // nil-out the presenceToRenew
        delegate.presenceToRenew = nil;
    });
    
    // Wait 500ms and stop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WPPresencePayload *stopPayload = [manager presenceWillStop];
        NSDate *now = [NSDate date];
        
        // Check startDate and untilDate
        XCTAssertEqualWithAccuracy(startDate.timeIntervalSince1970, stopPayload.fromDate.timeIntervalSince1970, 0.01);
        XCTAssertEqualWithAccuracy(now.timeIntervalSince1970, stopPayload.untilDate.timeIntervalSince1970, 0.01);
        
        // No auto-renew should have been attempted
        XCTAssertNil(delegate.presenceToRenew);
    });
    
    // Wait 950ms and check we're stopped still
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // No auto-renew should have been attempted
        XCTAssertNil(delegate.presenceToRenew);
        
        [expectation fulfill];
    });

    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}

/**
 Ensures we reset the auto-renew timer every time we start the presence.
 */
- (void)testMultiplePresenceDidStart {
    MockPresenceDelegate *delegate = [MockPresenceDelegate new];
    WPPresenceManager *manager = [[WPPresenceManager alloc]
                                  initWithAutoRenewDelegate:delegate
                                  anticipatedTime:0.3
                                  safetyMarginTime:0.1];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    __block NSDate *lastStartDate;
    for (int i = 0; i < 5; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            XCTAssertNil(delegate.presenceToRenew);
            [manager presenceDidStart];
            lastStartDate = [NSDate date];
        });
    }
    // Wait 500 + 210 ms and check the timer fired
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.71 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertNotNil(delegate.presenceToRenew);
        WPPresencePayload *stopPayload = [manager presenceWillStop];
        XCTAssertEqualWithAccuracy(lastStartDate.timeIntervalSince1970, stopPayload.fromDate.timeIntervalSince1970, 0.01);
        [expectation fulfill];
    });
    
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    [waiter waitForExpectations:@[expectation] timeout:2];
}

@end

