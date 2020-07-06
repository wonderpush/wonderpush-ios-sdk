//
//  WPSPISO8601DurationTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPISO8601Duration.h"
#import "WPSPExceptions.h"

@interface WPSPISO8601DurationTests : XCTestCase

@end

@implementation WPSPISO8601DurationTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testParseSuccess {
    
    NSArray *successCases = @[
        @[@"P", @[@YES, @0, @0, @0, @0, @0, @0, @0]],
        @[@"PT", @[@YES, @0, @0, @0, @0, @0, @0, @0]],
        @[@"-P", @[@NO, @0, @0, @0, @0, @0, @0, @0]],
        @[@"-PT", @[@NO, @0, @0, @0, @0, @0, @0, @0]],
        @[@"P1Y", @[@YES, @1, @0, @0, @0, @0, @0, @0]],
        @[@"+P1Y", @[@YES, @1, @0, @0, @0, @0, @0, @0]],
        @[@"-P1Y", @[@NO, @1, @0, @0, @0, @0, @0, @0]],
        @[@"P1Y2M3W4DT5H6M7S", @[@YES, @1, @2, @3, @4, @5, @6, @7]],
        @[@"P1.Y", @[@YES, @1, @0, @0, @0, @0, @0, @0]],
        @[@"P0.5Y", @[@YES, @.5, @0, @0, @0, @0, @0, @0]],
        @[@"P0,5Y", @[@YES, @.5, @0, @0, @0, @0, @0, @0]],
        @[@"P000.5Y", @[@YES, @.5, @0, @0, @0, @0, @0, @0]],
        @[@"P000,5Y", @[@YES, @.5, @0, @0, @0, @0, @0, @0]],
        @[@"P1.500Y", @[@YES, @1.5, @0, @0, @0, @0, @0, @0]],
        @[@"P1,500Y", @[@YES, @1.5, @0, @0, @0, @0, @0, @0]],
    ];
    
    for (NSArray *testCase in successCases) {
        NSString *input = testCase.firstObject;
        NSArray <NSNumber *> *durationComponents = testCase[1];
        WPSPISO8601Duration *expected = [[WPSPISO8601Duration alloc] initWithYears:durationComponents[1] months:durationComponents[2] weeks:durationComponents[3] days:durationComponents[4] hours:durationComponents[5] minutes:durationComponents[6] seconds:durationComponents[7] positive:durationComponents[0].boolValue];
        XCTAssertEqualObjects([WPSPISO8601Duration parse:input], expected);
    }
}
- (void)testParseErrors {
    NSArray *errorCases = @[@"", @" ", @" P1Y", @"P1Y ", @"P1H", @"P1S", @"P.5Y", @"P,5Y"];
    for (NSString *input in errorCases) {
        XCTAssertThrowsSpecific([WPSPISO8601Duration parse:input], WPSPBadInputException, @"Should have throw for bad input '%@'", input);
    }
}

- (void)testApplyTo {
    NSArray *testCases = @[
        @[@[@YES,  @0, @0, @0, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @1,  @0,  @0,  @0, @0]],
        @[@[@YES,  @1, @0, @0, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2001,  @1,  @1,  @0,  @0,  @0, @0]],
        @[@[@NO,   @1, @0, @0, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999,  @1,  @1,  @0,  @0,  @0, @0]],
        @[@[@YES,  @0, @1, @0, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @2,  @1,  @0,  @0,  @0, @0]],
        @[@[@NO,   @0, @1, @0, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12,  @1,  @0,  @0,  @0, @0]],
        @[@[@YES,  @0, @0, @1, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @8,  @0,  @0,  @0, @0]],
        @[@[@NO,   @0, @0, @1, @0, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12, @25,  @0,  @0,  @0, @0]],
        @[@[@YES,  @0, @0, @0, @1, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @2,  @0,  @0,  @0, @0]],
        @[@[@NO,   @0, @0, @0, @1, @0, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12, @31,  @0,  @0,  @0, @0]],
        @[@[@YES,  @0, @0, @0, @0, @1, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @1,  @1,  @0,  @0, @0]],
        @[@[@NO,   @0, @0, @0, @0, @1, @0, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12, @31, @23,  @0,  @0, @0]],
        @[@[@YES,  @0, @0, @0, @0, @0, @1, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @1,  @0,  @1,  @0, @0]],
        @[@[@NO,   @0, @0, @0, @0, @0, @1, @0], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12, @31, @23, @59,  @0, @0]],
        @[@[@YES,  @0, @0, @0, @0, @0, @0, @1], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @1,  @0,  @0,  @1, @0]],
        @[@[@NO,   @0, @0, @0, @0, @0, @0, @1], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12, @31, @23, @59, @59, @0]],
        @[@[@YES,  @0, @0, @0, @0, @0, @0, @.001], @[@2000, @1, @1, @0, @0, @0, @0], @[@2000,  @1,  @1,  @0,  @0,  @0,   @1]],
        @[@[@NO,   @0, @0, @0, @0, @0, @0, @.001], @[@2000, @1, @1, @0, @0, @0, @0], @[@1999, @12, @31, @23, @59, @59, @999]],
    ];
    
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorianCalendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    for (NSArray *testCase in testCases) {
        
        NSArray<NSNumber *> *durationComponents = testCase[0];
        NSArray<NSNumber *> *initialComponents = testCase[1];
        NSArray<NSNumber *> *expectedComponents = testCase[2];
        
        WPSPISO8601Duration *duration = [[WPSPISO8601Duration alloc] initWithYears:durationComponents[1] months:durationComponents[2] weeks:durationComponents[3] days:durationComponents[4] hours:durationComponents[5] minutes:durationComponents[6] seconds:durationComponents[7] positive:durationComponents[0].boolValue];
        
        NSDateComponents *initialDateComponents = [NSDateComponents new];
        initialDateComponents.year = initialComponents[0].integerValue;
        initialDateComponents.month = initialComponents[1].integerValue;
        initialDateComponents.day = initialComponents[2].integerValue;
        initialDateComponents.hour = initialComponents[3].integerValue;
        initialDateComponents.minute = initialComponents[4].integerValue;
        initialDateComponents.second = initialComponents[5].integerValue;
        initialDateComponents.nanosecond = initialComponents[6].integerValue * 1000000;

        NSDateComponents *expectedDateComponents = [NSDateComponents new];
        expectedDateComponents.year = expectedComponents[0].integerValue;
        expectedDateComponents.month = expectedComponents[1].integerValue;
        expectedDateComponents.day = expectedComponents[2].integerValue;
        expectedDateComponents.hour = expectedComponents[3].integerValue;
        expectedDateComponents.minute = expectedComponents[4].integerValue;
        expectedDateComponents.second = expectedComponents[5].integerValue;
        expectedDateComponents.nanosecond = expectedComponents[6].integerValue * 1000000;

        NSDate *initialDate = [gregorianCalendar dateFromComponents:initialDateComponents];
        NSDate *expectedDate = [gregorianCalendar dateFromComponents:expectedDateComponents];
        XCTAssertEqual([duration applyTo:initialDate].timeIntervalSince1970, expectedDate.timeIntervalSince1970);
    }
    
    
}

@end
