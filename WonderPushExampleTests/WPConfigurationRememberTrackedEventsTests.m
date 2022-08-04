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

- (void)setTrackedEvents:(NSArray *)trackedEvents;

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

- (void) assert:(id)subject contains:(NSString *)expected {
    XCTAssertTrue([subject isKindOfClass:NSDictionary.class], @"Not a dict: %@", subject);
    XCTAssertTrue([expected isKindOfClass:NSString.class], @"Not a string: %@", expected);

    id expectedDict = [self toJSON:expected];
    XCTAssertTrue([expectedDict isKindOfClass:NSDictionary.class], @"Not a dict: %@", expectedDict);

    NSEnumerator *keyEnumerator = [expectedDict keyEnumerator];
    id expectedKey;
    while ((expectedKey = [keyEnumerator nextObject])) {
        XCTAssertTrue([expectedKey isKindOfClass:NSString.class], @"Not a string: %@", expectedKey);
        id expectedValue = expectedDict[expectedKey];
        XCTAssertEqualObjects(expectedValue, subject[expectedKey], @"Value differs for key %@", expectedKey);
    }
}

- (void) testAddEventAddsCollapsingLast {
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    XCTAssertEqual(3, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"test2\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
}

- (void) testAddEventWithCollapsingLast {
    // Note: Adding events with collapsing=last is not customary, but it we're testing the implementation here.
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(1, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"];
}

- (void) testAddEventWithCollapsingCampaign {
    // "campaign" collapsing are treated as already collapsed (so we don't add a collapsing=last event)
    // We deduplicate them based on their campaignId
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(1, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"campaign\"}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"campaignId\":\"c2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"campaignId\":\"c2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"campaign\"}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"campaignId\":\"c2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"];
}

- (void) testAddEventWithCollapsingUnhandled {
    // Unhandled collapsing are treated as already collapsed (so we don't add a collapsing=last event)
    // They accumulate like uncollapsed events do, there's no known deduplication to apply
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(1, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"];
    
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(3, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"];
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
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010001000,\"creationDate\":1000010001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010002000,\"creationDate\":1000010002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"];
    
    // Adding a collapsing=last event should only affect the same collapsing=last and identical type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"]; // <- Only thing changed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010002000,\"creationDate\":1000010002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"];
    
    // Adding a collapsing=campaign event should only affect the same collapsing=campaign and identical campaignId
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"]; // <- Only thing changed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"];
    
    // Adding an unhandled collapsing event should merely add a new event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010006000,\"creationDate\":1000010006000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(9, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010004000,\"creationDate\":1000010004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010006000,\"creationDate\":1000010006000,\"collapsing\":\"unhandled~collapsing\"}"]; // <- Only thing added
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"];
    
    // Adding an uncollapsed event should add a new event and only affect the collapsing=last and same type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010007000,\"creationDate\":1000010007000}"]];
    XCTAssertEqual(10, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010007000,\"creationDate\":1000010007000,\"collapsing\":\"last\"}"]; // <- Thing changed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010003000,\"creationDate\":1000010003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010005000,\"creationDate\":1000010005000,\"collapsing\":\"campaign\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010006000,\"creationDate\":1000010006000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"test1\",\"campaignId\":\"c1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010000000,\"creationDate\":1000010000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"test2\",\"campaignId\":\"c2\",\"actionDate\":1000010007000,\"creationDate\":1000010007000}"]; // <- Thing added
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
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    
    // One more uncollapsed event of another type should consume one place too
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]];
    XCTAssertEqual(7, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"];
    
    // One more collapsed event should not, however
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"unhandled~collapsing\"}"]];
    XCTAssertEqual(8, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"];
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
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]; // uncollapsed-test1 was removed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    
    // One more uncollapsed event of a previous type should bump an existing collapsing=last event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]; // <- Only this one is bumped
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]; // <- and uncollapsed event is tracked as we are below the corresponding maximum
    
    // Adding directly one collapsing=last should also remove the oldest collapsing=last to respect the max
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]; // uncollapsed-test3 was removed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]; // <- this one took its place
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"];
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
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"]; // @BUILTIN1 was removed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    
    // One more uncollapsed event of a previous type should bump an existing collapsing=last event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"]; // <- Only this one is bumped
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"]; // <- and uncollapsed event is tracked as we are below the corresponding maximum
    
    // Adding directly one collapsing=last should also remove the oldest collapsing=last to respect the max
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"@BUILTIN7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]];
    XCTAssertEqual(12, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"]; // @BUILTIN3 was removed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"@BUILTIN7\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"last\"}"]; // <- this one took its place
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"@BUILTIN1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"@BUILTIN3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11] contains:@"{\"type\":\"@BUILTIN2\",\"actionDate\":1000000006000,\"creationDate\":1000000006000}"];
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
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"unhandled~collapsing\"}"]; // uncollapsed-test1 was removed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"];
    
    // One more collapsing=campaign event, even of a previous type, should remove the oldest one
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]];
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"]; // uncollapsed-test2 was removed
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000006000,\"creationDate\":1000000006000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"];
    
    // One more collapsing=campaign event should replace its previous occurence, not removing any other event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]];
    XCTAssertEqual(5, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000007000,\"creationDate\":1000000007000,\"collapsing\":\"campaign\",\"campaignId\":\"c1\"}"]; // <- this one was updated
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
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"@BUILTIN4\",\"actionDate\":1000000003010,\"creationDate\":1000000003010,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"@BUILTIN5\",\"actionDate\":1000000004010,\"creationDate\":1000000004010,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005010,\"creationDate\":1000000005010,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":1000000003000,\"creationDate\":1000000003000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test5\",\"actionDate\":1000000004000,\"creationDate\":1000000004000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:6] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:7] contains:@"{\"type\":\"unhandled~collapsing2\",\"actionDate\":1000000001020,\"creationDate\":1000000001020,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:8] contains:@"{\"type\":\"unhandled~collapsing3\",\"actionDate\":1000000002020,\"creationDate\":1000000002020,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:9] contains:@"{\"type\":\"unhandled~collapsing4\",\"actionDate\":1000000003020,\"creationDate\":1000000003020,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:10] contains:@"{\"type\":\"unhandled~collapsing5\",\"actionDate\":1000000004020,\"creationDate\":1000000004020,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:11] contains:@"{\"type\":\"unhandled~collapsing6\",\"actionDate\":1000000005020,\"creationDate\":1000000005020,\"collapsing\":\"unhandled~collapsing\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:12] contains:@"{\"type\":\"uncollapsed-test6\",\"actionDate\":1000000005000,\"creationDate\":1000000005000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:13] contains:@"{\"type\":\"@BUILTIN6\",\"actionDate\":1000000005010,\"creationDate\":1000000005010}"];
}

- (void) testUncollapsedEventsAgePruning {
    WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs = 1000000000000;
    
    // Add one too many uncollapsed event with different type
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"]];
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"]];
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    
    // Advance time
    // NOTE: Time still flows, so if tests are slow (here more than 500ms), the results will be broken
    WPConfiguration.sharedConfiguration.now = ^{
        return [NSDate dateWithTimeIntervalSince1970:2000000001.500];
    };
    
    // Implementation detail: The getter does not apply pruning, so the list is unchanged
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    
    // Add one more event
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":2000000000000,\"creationDate\":2000000000000}"]]; // yes, this event is 1500ms in the past, it's fine
    // Pruning should have been applied
    XCTAssertEqual(6, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"uncollapsed-test1\",\"actionDate\":1000000000000,\"creationDate\":1000000000000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"uncollapsed-test2\",\"actionDate\":1000000001000,\"creationDate\":1000000001000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:3] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":2000000000000,\"creationDate\":2000000000000,\"collapsing\":\"last\"}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:4] contains:@"{\"type\":\"uncollapsed-test3\",\"actionDate\":1000000002000,\"creationDate\":1000000002000}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:5] contains:@"{\"type\":\"uncollapsed-test4\",\"actionDate\":2000000000000,\"creationDate\":2000000000000}"];
}

- (void) testOccurrencesStorage {
    // Checks that the "occurrences" dictionary is added to both collapsed and uncollapsed events in the event storage

    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000000,\"creationDate\":1000000000000}"]];
    XCTAssertEqual(2, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"collapsing\":\"last\",\"occurrences\": {\"allTime\":1,\"last1days\":1,\"last3days\":1,\"last7days\":1,\"last15days\":1,\"last30days\":1,\"last60days\":1,\"last90days\":1}}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"occurrences\": {\"allTime\":1,\"last1days\":1,\"last3days\":1,\"last7days\":1,\"last15days\":1,\"last30days\":1,\"last60days\":1,\"last90days\":1}}"];

    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\",\"actionDate\":1000000000001,\"creationDate\":1000000000000}"]];
    XCTAssertEqual(3, WPConfiguration.sharedConfiguration.trackedEvents.count);
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:0] contains:@"{\"type\":\"test\",\"collapsing\":\"last\",\"occurrences\": {\"allTime\":2,\"last1days\":2,\"last3days\":2,\"last7days\":2,\"last15days\":2,\"last30days\":2,\"last60days\":2,\"last90days\":2}}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:1] contains:@"{\"type\":\"test\",\"occurrences\": {\"allTime\":1,\"last1days\":1,\"last3days\":1,\"last7days\":1,\"last15days\":1,\"last30days\":1,\"last60days\":1,\"last90days\":1}}"];
    [self assert:[WPConfiguration.sharedConfiguration.trackedEvents objectAtIndex:2] contains:@"{\"type\":\"test\",\"occurrences\": {\"allTime\":2,\"last1days\":2,\"last3days\":2,\"last7days\":2,\"last15days\":2,\"last30days\":2,\"last60days\":2,\"last90days\":2}}"];
}

- (void) testOccurrencesDays {
    // Checks the lastXdays entries of the occurrences

    NSInteger now = [WPConfiguration.sharedConfiguration.now() timeIntervalSince1970] * 1000;
    NSInteger eventMaxAgeDays = WPConfiguration.sharedConfiguration.maximumUncollapsedTrackedEventsAgeMs / 86400000;
    for (NSInteger i = 0; i < 100; i++) {
        NSInteger actionDate = now - i * 86400000;
        NSDictionary *event = @{@"type": @"test", @"actionDate": @(actionDate), @"creationDate": @(now)};
        NSDictionary *occurrences;
        [WPConfiguration.sharedConfiguration rememberTrackedEvent:event occurrences:&occurrences];
        for (NSNumber *daysObj in @[@(1), @(3), @(7), @(15), @(30), @(60), @(90)]) {
            NSInteger days = daysObj.integerValue;
            NSInteger expectedNumberOfEvents = MIN(days, i) + 1;
            expectedNumberOfEvents = MIN(expectedNumberOfEvents, eventMaxAgeDays); //Whatever happens we don't store events from eventMaxAgeDays ago or older
            switch (days) {
                case 1:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last1days"] integerValue]);
                    break;
                case 3:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last3days"] integerValue]);
                    break;
                case 7:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last7days"] integerValue]);
                    break;
                case 15:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last15days"] integerValue]);
                    break;
                case 30:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last30days"] integerValue]);
                    break;
                case 60:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last60days"] integerValue]);
                    break;
                case 90:
                    XCTAssertEqual(expectedNumberOfEvents, [occurrences[@"last90days"] integerValue], @"i=%ld expected=%ld", (long)i, (long)expectedNumberOfEvents);
                    break;
            }
        }
    }
}

- (void) testOccurrencesAllTimeCollapsingLast {
    // Adding uncollapsed events and collapsing=last event has the same effect on the allTime count:
    // It increments the allTime count
    NSDictionary *occurrences = nil;
    // Altername between the 2 collapsing options
    NSArray *collapsings = @[@"last", NSNull.null];

    for (NSInteger i = 0; i < 1000; i++) {
        NSMutableDictionary *eventData = [NSMutableDictionary new];
        eventData[@"type"] = @"test";
        eventData[@"actionDate"] = [NSNumber numberWithInteger:1000000000000];
        eventData[@"creationDate"] = [NSNumber numberWithInteger:1000000000000];
        eventData[@"campaignId"] = @"c1";
        id collapsing = collapsings[i % collapsings.count];
        if ([collapsings isKindOfClass:NSString.class]) {
            eventData[@"collapsing"] = collapsing;
        }
        [WPConfiguration.sharedConfiguration rememberTrackedEvent:eventData occurrences:&occurrences];
        XCTAssertEqual(i + 1, [occurrences[@"allTime"] integerValue]);

        // Find the collapsed version and check its "occurrences" property
        BOOL found = NO;
        for(id event in WPConfiguration.sharedConfiguration.trackedEvents) {
            if ([event[@"type"] isEqualToString:@"test"]
                && [event[@"collapsing"] isEqualToString:@"last"]) {
                found = YES;
                XCTAssertEqual([occurrences[@"allTime"] integerValue], [event[@"occurrences"][@"allTime"] integerValue]);
                break;
            }
        }
        XCTAssertTrue(found);
    }
}

- (void) testOccurrencesAllTimeCollapsingCampaign {
    // Adding collapsing=campaign event only increments the allTime count for that campaign
    NSDictionary *occurrences;
    for (NSString *campaignId in @[@"c1", @"c2"]) {
        for (NSInteger i = 0; i < 1000; i++) {
            NSMutableDictionary *eventData = [NSMutableDictionary new];
            eventData[@"type"] = @"test";
            eventData[@"actionDate"] = [NSNumber numberWithInteger:1000000000000];
            eventData[@"creationDate"] = [NSNumber numberWithInteger:1000000000000];
            eventData[@"campaignId"] = campaignId;
            eventData[@"collapsing"] = @"campaign";
            [WPConfiguration.sharedConfiguration rememberTrackedEvent:eventData occurrences:&occurrences];
            XCTAssertEqual(i + 1, [occurrences[@"allTime"] integerValue]);
            
            // Find the collapsed version and check its "allTime" count
            BOOL found = NO;
            for(id event in WPConfiguration.sharedConfiguration.trackedEvents) {
                if ([event[@"type"] isEqualToString:@"test"]
                    && [event[@"collapsing"] isEqualToString:@"campaign"]
                    && [event[@"campaignId"] isEqualToString:campaignId]) {
                    found = YES;
                    XCTAssertEqual([occurrences[@"allTime"] integerValue], [event[@"occurrences"][@"allTime"] integerValue]);
                    break;
                }
            }
            XCTAssertTrue(found);
        }
    }
    
}

- (void) testOccurrencesAllTimeCollapsingUnhandled {
    // Adding collapsing=unhandled event sets a allTime count of 1 for each event
    NSDictionary *occurrences;
    for (NSInteger i = 0; i < 1000; i++) {
        NSMutableDictionary *eventData = [NSMutableDictionary new];
        eventData[@"type"] = @"test";
        eventData[@"actionDate"] = [NSNumber numberWithInteger:1000000000000];
        eventData[@"creationDate"] = [NSNumber numberWithInteger:1000000000000];
        eventData[@"collapsing"] = @"unhandled~collapsing";
        [WPConfiguration.sharedConfiguration rememberTrackedEvent:eventData occurrences:&occurrences];
        XCTAssertEqual(1, [occurrences[@"allTime"] integerValue]);
    }

    for(id event in WPConfiguration.sharedConfiguration.trackedEvents) {
        if ([event[@"type"] isEqualToString:@"test"]
            && [event[@"collapsing"] isEqualToString:@"unhandled~collapsing"]) {
            XCTAssertEqual(1, [event[@"occurrences"][@"allTime"] integerValue]);
            break;
        }
    }

}

- (void) testMigration {
    // This checks that the allTime counter is always at least the number of uncollapsed events of the same type
    // This is useful when the collapsed event doesn't hold the allTime info,
    // which is most likely when people will upgrade to the new SDK that counts occurrences

    NSMutableArray *trackedEvents = [NSMutableArray new];
    [trackedEvents addObject:[self toJSON:@"{\"type\":\"test\", \"collapsing\": \"last\", \"actionDate\": 1000000000000, \"creationDate\":1000000000000}"]];
    [trackedEvents addObject:[self toJSON:@"{\"type\":\"another\", \"collapsing\": \"last\", \"actionDate\": 1000000000000, \"creationDate\":1000000000000}"]];
    for (int i = 0; i < 20; i++) {
        [trackedEvents addObject:[self toJSON:@"{\"type\":\"test\", \"actionDate\": 1000000000000, \"creationDate\":1000000000000}"]];
        [trackedEvents addObject:[self toJSON:@"{\"type\":\"another\", \"actionDate\": 1000000000000, \"creationDate\":1000000000000}"]];
    }
    WPConfiguration.sharedConfiguration.trackedEvents = [NSArray arrayWithArray:trackedEvents];
    NSDictionary *occurrences = nil;

    // Add an unrelated event, making sure this doesn't affect the occurrences of "test"
    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"yetanother\", \"actionDate\": 1000000000000, \"creationDate\":1000000000000}"] occurrences:&occurrences];
    XCTAssertEqual(1, [occurrences[@"allTime"] integerValue]);

    [WPConfiguration.sharedConfiguration rememberTrackedEvent:[self toJSON:@"{\"type\":\"test\", \"actionDate\": 1000000000000, \"creationDate\":1000000000000}"] occurrences:&occurrences];
    XCTAssertEqual(21, [occurrences[@"allTime"] integerValue]);
}

@end
