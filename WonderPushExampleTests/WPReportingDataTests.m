//
//  WPReportingDataTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 03/10/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPReportingData.h"
@interface WPReportingDataTests : XCTestCase

@end

@implementation WPReportingDataTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testReportingAttributionReason {
    WPReportingData *reportingData;
    NSDictionary *result;
    
    // eventData is nil: attributionReason written
    reportingData = [[WPReportingData alloc] initWithNotificationId:nil campaignId:@"123" viewId:nil reporting:nil];
    result = [reportingData filledEventData:nil attributionReason:WPReportingAttributionReasonInAppViewed];
    XCTAssertEqual(WPReportingAttributionReasonInAppViewed, [result valueForKeyPath:@"reporting.attributionReason"]);
    XCTAssertEqual(@"123", [result valueForKeyPath:@"campaignId"]);
    
    // eventData is empty
    // reporting has content
    // => attributionReason written
    reportingData = [[WPReportingData alloc] initWithNotificationId:nil campaignId:@"123" viewId:nil reporting:@{@"foo": @"bar"}];
    result = [reportingData filledEventData:@{} attributionReason:WPReportingAttributionReasonInAppViewed];
    XCTAssertEqual(WPReportingAttributionReasonInAppViewed, [result valueForKeyPath:@"reporting.attributionReason"]);
    XCTAssertEqual(@"bar", [result valueForKeyPath:@"reporting.foo"]);
    XCTAssertEqual(@"123", [result valueForKeyPath:@"campaignId"]);
    
    // eventData is empty
    // reporting is nil
    // => attributionReason written
    reportingData = [[WPReportingData alloc] initWithNotificationId:nil campaignId:@"123" viewId:nil reporting:nil];
    result = [reportingData filledEventData:@{} attributionReason:WPReportingAttributionReasonInAppViewed];
    XCTAssertEqual(WPReportingAttributionReasonInAppViewed, [result valueForKeyPath:@"reporting.attributionReason"]);
    XCTAssertEqual(@"123", [result valueForKeyPath:@"campaignId"]);
    
    // eventData has campaignId
    // reporting is nil
    // => attributionReason not written
    reportingData = [[WPReportingData alloc] initWithNotificationId:nil campaignId:@"123" viewId:nil reporting:nil];
    result = [reportingData filledEventData:@{@"campaignId": @"456"} attributionReason:WPReportingAttributionReasonInAppViewed];
    XCTAssertNil([result valueForKeyPath:@"reporting.attributionReason"]);
    XCTAssertEqual(@"456", [result valueForKeyPath:@"campaignId"]);
    
    // eventData has notificationId
    // reporting is nil
    // => attributionReason not written
    reportingData = [[WPReportingData alloc] initWithNotificationId:nil campaignId:@"123" viewId:nil reporting:nil];
    result = [reportingData filledEventData:@{@"notificationId": @"456"} attributionReason:WPReportingAttributionReasonInAppViewed];
    XCTAssertNil([result valueForKeyPath:@"reporting.attributionReason"]);
    XCTAssertEqual(@"456", [result valueForKeyPath:@"notificationId"]);
    XCTAssertNil([result valueForKeyPath:@"campaignId"]);
    
    // eventData has viewId
    // reporting is nil
    // => attributionReason not written
    reportingData = [[WPReportingData alloc] initWithNotificationId:nil campaignId:@"123" viewId:nil reporting:nil];
    result = [reportingData filledEventData:@{@"viewId": @"456"} attributionReason:WPReportingAttributionReasonInAppViewed];
    XCTAssertNil([result valueForKeyPath:@"reporting.attributionReason"]);
    XCTAssertEqual(@"456", [result valueForKeyPath:@"viewId"]);
    XCTAssertNil([result valueForKeyPath:@"campaignId"]);
}

@end
