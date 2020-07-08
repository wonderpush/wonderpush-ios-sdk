//
//  WPSPSegmenterTests.m
//  WonderPushExampleTests
//
//  Created by Olivier Favre on 7/7/20.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPSegmenter.h"
#import "WPUtil.h"

@interface WPSPSegmenterTests : XCTestCase

@end

static WPSPSegmenterData * _Nonnull emptyData = nil;

@interface WPSPSegmenterData (private)

- (WPSPSegmenterData *) withInstallation:(NSDictionary *)installation;
- (WPSPSegmenterData *) withAllEvents:(NSArray<NSDictionary *> *)allEvents;
- (WPSPSegmenterData *) withNewerEvent:(NSDictionary *)newerEvent;

@end

@implementation WPSPSegmenterData (private)

- (WPSPSegmenterData *) withInstallation:(NSDictionary *)installation {
    return [[WPSPSegmenterData alloc] initWithInstallation:installation allEvents:self.allEvents presenceInfo:self.presenceInfo lastAppOpenDate:self.lastAppOpenDate];
}

- (WPSPSegmenterData *)withAllEvents:(NSArray<NSDictionary *> *)allEvents {
    return [[WPSPSegmenterData alloc] initWithInstallation:self.installation allEvents:[NSArray arrayWithArray:allEvents] presenceInfo:self.presenceInfo lastAppOpenDate:self.lastAppOpenDate];
}

- (WPSPSegmenterData *)withPresenceInfo:(WPSPSegmenterPresenceInfo *)presenceInfo {
    return [[WPSPSegmenterData alloc] initWithInstallation:self.installation allEvents:self.allEvents presenceInfo:presenceInfo lastAppOpenDate:self.lastAppOpenDate];
}

- (WPSPSegmenterData *)withLastAppOpenDate:(long long)lastAppOpenDate {
    return [[WPSPSegmenterData alloc] initWithInstallation:self.installation allEvents:self.allEvents presenceInfo:self.presenceInfo lastAppOpenDate:lastAppOpenDate];
}

- (WPSPSegmenterData *)withNewerEvent:(NSDictionary *)newerEvent {
    NSMutableArray *allEvents = [NSMutableArray arrayWithCapacity:self.allEvents.count + 1];
    NSString *newerEventType = newerEvent[@"type"];
    for (NSDictionary *event in self.allEvents) {
        NSString *eventType = event[@"type"];
        if (![newerEventType isEqualToString:eventType]) {
            [allEvents addObject:event];
        }
    }
    [allEvents addObject:newerEvent];
    return [self withAllEvents:allEvents];
}

@end

id parseJson(NSString *input) {
    NSError *error = nil;
    id rtn = [NSJSONSerialization JSONObjectWithData:[input dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error) @throw [NSException exceptionWithName:error.domain reason:@"Failed to parse JSON" userInfo:@{ @"error": error }];
    return rtn;
}

@implementation WPSPSegmenterTests

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        emptyData = [[WPSPSegmenterData alloc] initWithInstallation:@{} allEvents:@[] presenceInfo:nil lastAppOpenDate:0];
    });
}

+ (WPSPSegmenterData *) data:(WPSPSegmenterData *)data withInstallation:(NSDictionary *)installation {
    return [[WPSPSegmenterData alloc] initWithInstallation:installation allEvents:data.allEvents presenceInfo:data.presenceInfo lastAppOpenDate:data.lastAppOpenDate];
}

- (void) testItShouldMatchAll {
    WPSPSegmenter *s = [[WPSPSegmenter alloc] initWithData:emptyData];
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{}];
    XCTAssertTrue([s parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqNull {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": NSNull.null } }];
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ NSNull.null, NSNull.null] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", NSNull.null ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqFalse {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": @NO } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @NO ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqTrue {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": @YES } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @NO ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEq0 {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithInteger:0] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:0.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:1] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @1, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEq00 {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithDouble:0.0] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:0.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:1] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @1, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEq1 {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithInteger:1] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:0.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:1] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @1, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEq10 {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithDouble:1.0] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:0.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:1] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @1, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqDecimal {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithDouble:1.5] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:0.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:1] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.2] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.5] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.7] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:2.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:2] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @1.5, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqLong {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithLongLong:9223372036854775807LL] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775806}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775807}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775808}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    // When comparing a long with a double, we loose some precision, it's OK
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9.223372036854775806e18}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9.223372036854775807e18}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9.223372036854775808e18}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithDouble:7.000000000000000512e18] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":6999999999999999487}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":6999999999999999488}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":7000000000000000001}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":7000000000000000512}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":7000000000000000513}")]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqBigDecimal {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": [NSNumber numberWithDouble:1e300] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:0.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithInteger:1] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:1.0] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\": 1e300}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\": 1.0e300}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @1e300, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqBar {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": @"bar" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooEqEmptyString {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": @"" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"bar", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @[ @0, @"", @YES ] })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldcustomDateFooEqNumber {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".custom.date_foo": @{ @"eq": @1577836800000 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": NSNull.null } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @1 } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @NO } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"foo" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @1577836800000 } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2029-09-09T09:09:09.009+09:09" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T01:00:00.000+01:00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00:00.000Z" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00:00.000" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00:00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020Z" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldcustomDateFooEqString {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".custom.date_foo": @{ @"eq": @{ @"date": @"2020-01-01T00:00:00.000Z" } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": NSNull.null } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @1 } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @NO } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"foo" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @1577836800000 } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2029-09-09T09:09:09.009+09:09" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T01:00:00.000+01:00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00:00.000Z" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00:00.000" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00:00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00:00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01T00" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01-01" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020-01" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"custom": @{ @"date_foo": @"2020Z" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooComparisonLong {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gt": [NSNumber numberWithLongLong:9223372036854775806LL] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775805}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775806}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775807}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    // When comparing a long with a double, we loose some precision, it's OK
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9.223372036854775808e18}")]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": [NSNumber numberWithDouble:9.223372036854777000e18] }]] parsedSegmentMatchesInstallation:parsedSegment]);
    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lt": [NSNumber numberWithDouble:9.223372036854775808e18] } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:parseJson(@"{\"foo\":9223372036854775805}")]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooComparisonIntegers {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lt": @0 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @-1 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1 }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lte": @0 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @-1 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1 }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gt": @0 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @-1 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1 }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gte": @0 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @-1 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @0 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1 }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooComparisonDecimals {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lt": @1.5 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.2 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.5 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.7 }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lte": @1.5 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.2 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.5 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.7 }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gt": @1.5 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.2 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.5 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.7 }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gte": @1.5 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.2 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.5 }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @1.7 }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooComparisonStrings {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lt": @"mm" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"m" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"ma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"MM" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mm" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mz" }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lte": @"mm" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"m" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"ma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"MM" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mm" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mz" }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gt": @"mm" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"m" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"ma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"MM" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mm" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mz" }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gte": @"mm" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"m" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"ma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"MM" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mm" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mma" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"mz" }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchFieldFooComparisonBooleans {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lt": @YES } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lte": @YES } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gt": @YES } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gte": @YES } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lt": @NO } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"lte": @NO } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gt": @NO } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"gte": @NO } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @NO }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @YES }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchEventTypeTest {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"event": @{ @".type": @{ @"eq": @"test" } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withNewerEvent:@{ @"type": @"@APP_OPEN" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withNewerEvent:@{ @"type": @"test" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[[emptyData withNewerEvent:@{ @"type": @"@APP_OPEN" }] withNewerEvent:@{ @"type": @"test" }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchInstallation {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".bar": @{ @".sub": @{ @"eq": @"sub" }, @"installation": @{ @".foo": @{ @"eq": @"foo" } } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"bar": @{ @"sub": @"sub" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @"foo", @"bar": @{ @"sub": @"sub" } })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchEventInstallation {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"event": @{ @".type": @{ @"eq": @"test" }, @"installation": @{ @".foo": @{ @"eq": @"foo" } } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[[emptyData withInstallation:@{ @"foo": @"foo" }] withNewerEvent:@{ @"type": @"nope" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[[emptyData withInstallation:@{ @"foo": @"foo" }] withNewerEvent:@{ @"type": @"test" }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchAnd {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"eq": @"foo" }, @".bar": @{ @"eq": @"bar" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"bar": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @"foo", @"bar": @"bar" })]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"and": @[ @{ @".foo": @{ @"eq": @"foo" } }, @{ @".bar": @{ @"eq": @"bar" } } ] }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"bar": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @"foo", @"bar": @"bar" })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchOr {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"or": @[ @{ @".foo": @{ @"eq": @"foo" } }, @{ @".bar": @{ @"eq": @"bar" } } ] }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"to": @"to" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"bar": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @"foo", @"bar": @"bar" })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchNot {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"not": @{ @".foo": @{ @"eq": @"foo" } } }];
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"bar": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"foo": @"foo", @"bar": @"bar" })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchUnknownCriterion {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"unknown criterion": @{ } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchsubscriptionStatus {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"subscriptionStatus": @"optOut" }];
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": @{ @"data": NSNull.null } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": @{ @"data": @"FAKE" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": NSNull.null } })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": @"optIn" } })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": @"optOut" } })]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"subscriptionStatus": @"softOptOut" }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": @{ @"data": NSNull.null } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": @{ @"data": @"FAKE" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": NSNull.null } })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": @"optIn" } })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": @"optOut" } })]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"subscriptionStatus": @"optIn" }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": NSNull.null }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": @{ @"data": NSNull.null } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"pushToken": @{ @"data": @"FAKE" } }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": NSNull.null } })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": @"optIn" } })]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:(@{ @"pushToken": @{ @"data": @"FAKE" }, @"preferences": @{ @"subscriptionStatus": @"optOut" } })]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchLastActivityDate {
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"lastActivityDate": @{ @"gt": @1000000000000 } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withLastAppOpenDate:999999999999]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withLastAppOpenDate:1000000000000]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withLastAppOpenDate:1000000000001]] parsedSegmentMatchesInstallation:parsedSegment]);

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"lastActivityDate": @{ @"gt": @{ @"date": @"-PT1M" } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withLastAppOpenDate:[WPUtil getServerDate]]] parsedSegmentMatchesInstallation:parsedSegment]);
}

- (void) testItShouldMatchPresence {
    long long now = [WPUtil getServerDate];
    WPSPASTCriterionNode *parsedSegment;

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @NO } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 60000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @YES } }];
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 60000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @NO, @"elapsedTime": @{ @"gt": @1000 } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 60000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present, and it will last 60, so we pass

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @YES, @"elapsedTime": @{ @"gt": @1000 } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 60000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @NO, @"elapsedTime": @{ @"lt": @1000 } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 60000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @YES, @"elapsedTime": @{ @"lt": @1000 } } }];
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 60000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @NO, @"sinceDate": @{ @"lte": @{ @"date": @"-PT1M" } } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 100000 elapsedTime:20000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now - 30000 elapsedTime:30000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, but leave date is not lte -PT1M

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @YES, @"sinceDate": @{ @"lte": @{ @"date": @"-PT1M" } } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 100000 elapsedTime:20000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now - 30000 elapsedTime:30000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 30000 untilDate:now + 60000 elapsedTime:90000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now + 60000 elapsedTime:180000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, so not present

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @NO, @"sinceDate": @{ @"gte": @{ @"date": @"-PT1M" } } } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 100000 elapsedTime:20000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now - 30000 elapsedTime:30000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now + 60000 elapsedTime:120000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 120000 untilDate:now + 180000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, and leave date is gte -PT1M

    parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @"presence": @{ @"present": @YES, @"sinceDate": @{ @"gte": @{ @"date": @"-PT1M" } } } }];
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]); // no info is considered present since just about now
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now - 100000 elapsedTime:20000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 60000 untilDate:now - 30000 elapsedTime:30000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 30000 untilDate:now + 60000 elapsedTime:90000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now - 120000 untilDate:now + 60000 elapsedTime:180000]]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withPresenceInfo:[[WPSPSegmenterPresenceInfo alloc] initWithFromDate:now + 60000 untilDate:now + 120000 elapsedTime:60000]]] parsedSegmentMatchesInstallation:parsedSegment]); // not present yet, but leave date is gte -PT1M
}

- (void) testItShouldMatchPrefix {
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{ @".foo": @{ @"prefix": @"fo" } }];
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:emptyData] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"bar" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"foo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertTrue([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"fo" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"f" }]] parsedSegmentMatchesInstallation:parsedSegment]);
    XCTAssertFalse([[[WPSPSegmenter alloc] initWithData:[emptyData withInstallation:@{ @"foo": @"FOO" }]] parsedSegmentMatchesInstallation:parsedSegment]);
}

@end
