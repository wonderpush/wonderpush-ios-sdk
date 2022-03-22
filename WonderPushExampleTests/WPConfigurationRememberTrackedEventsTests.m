//
//  WPConfigurationRememberTrackedEventsTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 21/03/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPConfiguration.h"

@interface WPConfiguration (Testing)

@property (nonatomic, strong) NSDate * (^now)(void);

@end

@interface WPConfigurationRememberTrackedEventsTests : XCTestCase

@end

@implementation WPConfigurationRememberTrackedEventsTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    WPConfiguration.sharedConfiguration.now = ^{
        return [NSDate dateWithTimeIntervalSince1970:1000000000];
    };
    [WPConfiguration.sharedConfiguration clearStorageKeepUserConsent:YES keepDeviceId:YES];
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsCount = DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_COUNT;
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs = DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_AGE_MS;
    WPConfiguration.sharedConfiguration.maximumCollapsedOtherTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_OTHER_TRACKED_EVENTS_COUNT;
    WPConfiguration.sharedConfiguration.maximumCollapsedLastCustomTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_LAST_CUSTOM_TRACKED_EVENTS_COUNT;
    WPConfiguration.sharedConfiguration.maximumCollapsedLastBuiltinTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_LAST_BUILTIN_TRACKED_EVENTS_COUNT;
}

- (void)tearDown {
    WPConfiguration.sharedConfiguration.now = nil;
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsCount = DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_COUNT;
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs = DEFAULT_MAXIMUM_UNCOLLAPSED_TRACKED_EVENTS_AGE_MS;
    WPConfiguration.sharedConfiguration.maximumCollapsedOtherTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_OTHER_TRACKED_EVENTS_COUNT;
    WPConfiguration.sharedConfiguration.maximumCollapsedLastCustomTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_LAST_CUSTOM_TRACKED_EVENTS_COUNT;
    WPConfiguration.sharedConfiguration.maximumCollapsedLastBuiltinTrackedEventsCount = DEFAULT_MAXIMUM_COLLAPSED_LAST_BUILTIN_TRACKED_EVENTS_COUNT;
    
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (id)toJSON:(NSString *)s {
    return [NSJSONSerialization JSONObjectWithData:[s dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

- (NSString *)toString:(id)json {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingSortedKeys error:nil] encoding:NSUTF8StringEncoding];
}

- (NSString *)sortKeys:(NSString *)jsonString {
    return [self toString:[self toJSON:jsonString]];
}

- (void) testAddEventAddsCollapsingLast {
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:[self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    XCTAssertEqual(3, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"test2\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
}

- (void) testAddEventWithCollapsingLast {
    // Note: Adding events with collapsing=last is not customary, but it we're testing the implementation here.
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(1, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]);
}

- (void) testAddEventWithCollapsingCampaign {
    // "campaign" collapsing are treated as already collapsed (so we don't add a collapsing=last event)
    // We deduplicate them based on their campaignId
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(1, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"campaign\"}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"campaignId\":\"c2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"campaignId\":\"c2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"campaign\"}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"campaignId\":\"c2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]);
}

- (void) testAddEventWithCollapsingUnhandled {
    // Unhandled collapsing are treated as already collapsed (so we don't add a collapsing=last event)
    // They accumulate like uncollapsed events do, there's no known deduplication to apply
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(1, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]);
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(3, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]);
}

- (void) testNoCollapsingInterference {
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010001000,\"creationDate\":1000010001000,\"collapsing\":\"last\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010002000,\"creationDate\":1000010002000,\"collapsing\":\"campaign\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010001000,\"creationDate\":1000010001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010002000,\"creationDate\":1000010002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"]);
    
    // Adding a collapsing=last event should only affect the same collapsing=last and identical type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"]); // <- Only thing changed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010002000,\"creationDate\":1000010002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"]);
    
    // Adding a collapsing=campaign event should only affect the same collapsing=campaign and identical campaignId
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"]); // <- Only thing changed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"]);
    
    // Adding an unhandled collapsing event should merely add a new event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010006000,\"creationDate\":1000010006000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(9, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010006000,\"creationDate\":1000010006000,\"collapsing\":\"unhandled~collapsing\"}"]); // <- Only thing added
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"]);
    
    // Adding an uncollapsed event should add a new event and only affect the collapsing=last and same type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010007000,\"creationDate\":1000010007000}"]];
    XCTAssertEqual(10, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010007000,\"creationDate\":1000010007000,\"collapsing\":\"last\"}"]); // <- Thing changed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010006000,\"creationDate\":1000010006000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010007000,\"creationDate\":1000010007000}"]); // <- Thing added
}

- (void) testUncollapsedEventsSupernumeraryPruning {
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsCount = 5;
    
    // Add one too many uncollapsed event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]];
    
    // Ensure the oldest uncollapsed event is removed
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    
    // One more uncollapsed event of another type should consume one place too
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]];
    XCTAssertEqual(7, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]);
    
    // One more collapsed event should not, however
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]);
}

- (void) testCollapsingLastCustomEventsSupernumeraryPruning {
    WPConfiguration.sharedConfiguration.maximumCollapsedLastCustomTrackedEventsCount = 5;
    
    // Add one too many uncollapsed event with different type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]];
    // Ensure the oldest collapsing=last event is removed to respect the max
    XCTAssertEqual(11, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]); // uncollapsed-test1 was removed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    
    // One more uncollapsed event of a previous type should bump an existing collapsing=last event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]); // <- Only this one is bumped
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]); // <- and uncollapsed event is tracked as we are below the corresponding maximum
    
    // Adding directly one collapsing=last should also remove the oldest collapsing=last to respect the max
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]); // uncollapsed-test3 was removed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]); // <- this one took its place
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]);
}

- (void) testCollapsingLastBuiltinEventsSupernumeraryPruning {
    WPConfiguration.sharedConfiguration.maximumCollapsedLastBuiltinTrackedEventsCount = 5;
    
    // Add one too many uncollapsed event with different type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]];
    // Ensure the oldest collapsing=last event is removed to respect the max
    XCTAssertEqual(11, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]); // @BUILTIN1 was removed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    
    // One more uncollapsed event of a previous type should bump an existing collapsing=last event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]); // <- Only this one is bumped
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]); // <- and uncollapsed event is tracked as we are below the corresponding maximum
    
    // Adding directly one collapsing=last should also remove the oldest collapsing=last to respect the max
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]); // @BUILTIN3 was removed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"@BUILTIN7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]); // <- this one took its place
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11]], [self sortKeys:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]);
}

- (void) testCollapsingOtherEventsSupernumeraryPruning {
    WPConfiguration.sharedConfiguration.maximumCollapsedOtherTrackedEventsCount = 5;
    
    // Add one too many unhandled-collapsed event with different type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"]];
    // Ensure the oldest collapsed event is removed to respect the max
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]); // uncollapsed-test1 was removed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"]);
    
    // One more collapsing=campaign event, even of a previous type, should remove the oldest one
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]];
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]); // uncollapsed-test2 was removed
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]);
    
    // One more collapsing=campaign event should replace its previous occurence, not removing any other event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]];
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]); // <- this one was updated
}

- (void) testIndependentEventsSupernumeraryPruning {
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsCount = 2;
    WPConfiguration.sharedConfiguration.maximumCollapsedLastBuiltinTrackedEventsCount = 3;
    WPConfiguration.sharedConfiguration.maximumCollapsedLastCustomTrackedEventsCount = 4;
    WPConfiguration.sharedConfiguration.maximumCollapsedOtherTrackedEventsCount = 5;
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000010,\"creationDate\":1000000000010}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001010,\"creationDate\":1000000001010}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002010,\"creationDate\":1000000002010}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003010,\"creationDate\":1000000003010}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004010,\"creationDate\":1000000004010}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005010,\"creationDate\":1000000005010}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"unhandled~collapsing1\",\"actionDate\":1000000000020,\"creationDate\":1000000000020,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"unhandled~collapsing2\",\"actionDate\":1000000001020,\"creationDate\":1000000001020,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"unhandled~collapsing3\",\"actionDate\":1000000002020,\"creationDate\":1000000002020,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"unhandled~collapsing4\",\"actionDate\":1000000003020,\"creationDate\":1000000003020,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"unhandled~collapsing5\",\"actionDate\":1000000004020,\"creationDate\":1000000004020,\"collapsing\":\"unhandled~collapsing\"}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"unhandled~collapsing6\",\"actionDate\":1000000005020,\"creationDate\":1000000005020,\"collapsing\":\"unhandled~collapsing\"}"]];
    
    XCTAssertEqual(2+3+4+5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003010,\"creationDate\":1000000003010,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004010,\"creationDate\":1000000004010,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005010,\"creationDate\":1000000005010,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7]], [self sortKeys:@"{\"type\":\"unhandled~collapsing2\",\"actionDate\":1000000001020,\"creationDate\":1000000001020,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8]], [self sortKeys:@"{\"type\":\"unhandled~collapsing3\",\"actionDate\":1000000002020,\"creationDate\":1000000002020,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9]], [self sortKeys:@"{\"type\":\"unhandled~collapsing4\",\"actionDate\":1000000003020,\"creationDate\":1000000003020,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10]], [self sortKeys:@"{\"type\":\"unhandled~collapsing5\",\"actionDate\":1000000004020,\"creationDate\":1000000004020,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11]], [self sortKeys:@"{\"type\":\"unhandled~collapsing6\",\"actionDate\":1000000005020,\"creationDate\":1000000005020,\"collapsing\":\"unhandled~collapsing\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:12]], [self sortKeys:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:13]], [self sortKeys:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005010,\"creationDate\":1000000005010}"]);
}

- (void) testUncollapsedEventsAgePruning {
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs = 1000000000000;
    
    // Add one too many uncollapsed event with different type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    
    // Advance time
    // NOTE: Time still flows, so if tests are slow (here more than 500ms), the results will be broken
    WPConfiguration.sharedConfiguration.now = ^{
        return [NSDate dateWithTimeIntervalSince1970:2000000001.500];
    };
    
    // Implementation detail: The getter does not apply pruning, so the list is unchanged
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    
    // Add one more event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":2000000000000,\"creationDate\":2000000000000}"]]; // yes, this event is 1500ms in the past, it's fine
    // Pruning should have been applied
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0]], [self sortKeys:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1]], [self sortKeys:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":2000000000000,\"creationDate\":2000000000000,\"collapsing\":\"last\"}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4]], [self sortKeys:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]);
    XCTAssertEqualObjects([self toString:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5]], [self sortKeys:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":2000000000000,\"creationDate\":2000000000000}"]);
}

@end
