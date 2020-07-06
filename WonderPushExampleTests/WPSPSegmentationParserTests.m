//
//  WPSPSegmentationParserTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 06/07/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPSegmentationDSLParser.h"
#import "WPSPDefaultValueNodeParser.h"
#import "WPSPDefaultCriterionNodeParser.h"
#import "WPSPExceptions.h"
#import "WPSPGeohash.h"
#import "WPSPGeoCircle.h"

@interface WPSPSegmentationParserTests : XCTestCase

@end

static const WPSPSegmentationDSLParser *parser = nil;
@implementation WPSPSegmentationParserTests

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [WPSPSegmentationDSLParser defaultThrowingParser];
    });
    
}

- (void) testBadInput {

    // nil
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrowsSpecific([parser parse:nil dataSource:[WPSPInstallationSource new]], WPSPBadInputException, @"should fail");
    #pragma clang diagnostic pop
    
    NSString *JSON = @"[ \
    { \"\": \"\" }, \
    { \"eq\": 0 }, \
    { \"any\": [] }, \
    { \"all\": [] }, \
    { \"prefix\": \"a\" }, \
    { \"inside\": { \"geobox\": \"u\" } }, \
    { \".field\": {} }, \
    { \".field\": { \"\": \"\" } }, \
    { \".field\": { \"prefix\": 0 } }, \
    { \".field\": { \"gt\": [] } }, \
    { \".field\": { \"gt\": {} } }, \
    { \".field\": { \"gt\": { \"someType1\": 0, \"someType2\": 0 } } }, \
    { \".field\": { \"gt\": { \"date\": false } } }, \
    { \".field\": { \"gt\": { \"date\": \"invalid\" } } }, \
    { \".field\": { \"gt\": { \"duration\": false } } }, \
    { \".field\": { \"gt\": { \"duration\": \"42 towels\" } } }, \
    { \".field\": { \"gt\": { \"duration\": \"P nope\" } } }, \
    { \".field\": { \"gt\": { \"duration\": \"nope\" } } }, \
    { \".field\": { \"gt\": { \"geolocation\": false } } }, \
    { \".field\": { \"inside\": { \"date\": 0 } } }, \
    { \".field\": { \"inside\": { \"geobox\": 0 } } }, \
    { \".field\": { \"inside\": { \"geobox\": {} } } }, \
    { \".field\": { \"inside\": { \"geobox\": { \"foo\": 0 } } } }, \
    { \".field\": { \"inside\": { \"geocircle\": 0 } } }, \
    { \".field\": { \"inside\": { \"geocircle\": {} } } }, \
    { \".field\": { \"inside\": { \"geocircle\": { \"radius\": true } } } }, \
    { \".field\": { \"inside\": { \"geocircle\": { \"radius\": 0, \"foo\": 0 } } } }, \
    { \".field\": { \"inside\": { \"geocircle\": { \"radius\": 0, \"lat\": true, \"lon\": 0 } } } }, \
    { \".field\": { \"inside\": { \"geocircle\": { \"radius\": 0, \"lat\": 0, \"lon\": true } } } }, \
    { \".field\": { \"inside\": { \"geocircle\": { \"radius\": 0, \"center\": true } } } }, \
    { \".field\": { \"inside\": { \"geopolygon\": 0 } } }, \
    { \".field\": { \"inside\": { \"geopolygon\": {} } } }, \
    { \".field\": { \"inside\": { \"geopolygon\": [] } } }, \
    { \".field\": { \"inside\": { \"geopolygon\": [ \"u\" ] } } }, \
    { \".field\": { \"inside\": { \"geopolygon\": [ \"u\", \"v\" ] } } }, \
    { \".field\": { \"all\": {} } }, \
    { \".field\": { \"any\": {} } }, \
    { \"and\": {} }, \
    { \"and\": 0 }, \
    { \"and\": [ null ] }, \
    { \"and\": [ 0 ] }, \
    { \"and\": [ false ] }, \
    { \"and\": [ \"\" ] }, \
    { \"and\": [ [] ] } \
    ]";
    
    NSError *error;
    NSArray *cases = [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    XCTAssertNil(error);
    for (id input in cases) {
        NSData *JSONData = [NSJSONSerialization dataWithJSONObject:input options:0 error:&error];
        XCTAssertNil(error);
        XCTAssertThrowsSpecific([parser parse:input dataSource:[WPSPInstallationSource new]], WPSPBadInputException, @"should fail: %@", [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding]);
    }
}

- (void)testUnknownCriterion {
    XCTAssertThrowsSpecific([parser parse:@{@".field": @{@"gloubiboulga": @"toto"}} dataSource:[WPSPInstallationSource new]], WPSPUnknownCriterionException, @"unknown criterion: gloubiboulga");
    XCTAssertThrowsSpecific([parser parse:@{@"gloubiboulga": @42} dataSource:[WPSPInstallationSource new]], WPSPUnknownCriterionException, @"unknown criterion: gloubiboulga");
}

- (void)testUnknownValue {
    XCTAssertThrowsSpecific([parser parse:@{@".field": @{@"gt": @{@"unknown type": @42}}} dataSource:[WPSPInstallationSource new]], WPSPUnknownValueException, @"unknown value");
}

- (void)testWithOrWithoutDataSource {
    NSArray *cases = @[
        @{@"gt": @0}, // only available with a data source
        @{ @".field": @{ @"not": @{ @"presence": @{ @"present": @YES } } } }, // only available without a data source
        @{ @".field": @{ @"not": @{ @"geo": @{ } } } }, // only available without a data source
        @{ @".field": @{ @"not": @{ @"event": @{} } } }, // only available without a data source
    ];
    
    for (NSDictionary *input in cases) {
        NSData *JSONData = [NSJSONSerialization dataWithJSONObject:input options:0 error:nil];
        XCTAssertThrowsSpecific([parser parse:input dataSource:[WPSPInstallationSource new]], WPSPBadInputException, @"bad input: %@", [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding]);

    }
}

- (void)testNoThrowCriterion {
    // it should not throw on unknown criterion when configured to
    WPSPDefaultValueNodeParser *defaultValueNodeParser = [WPSPDefaultValueNodeParser new];
    WPSPDefaultCriterionNodeParser *defaultCriterionNodeParser = [WPSPDefaultCriterionNodeParser new];
    WPSPParserConfig *parserConfig = [[WPSPParserConfig alloc]
                                      initWithValueParser:VALUE_NODE_PARSER_BLOCK { return [defaultValueNodeParser parseValueWithContext:context key:key input:input]; }
                                      criterionParser:CRITERION_NODE_PARSER_BLOCK { return [defaultCriterionNodeParser parseCriterionWithContext:context key:key input:input]; }
                                      throwOnUnknownCriterion:NO
                                      throwOnUnknownValue:YES];
    WPSPSegmentationDSLParser *parserLenientCriterion = [[WPSPSegmentationDSLParser alloc] initWithParserConfig:parserConfig];
    
    NSString *unknownCriterionKey = @"INEXISTENT CRITERION";
    NSString *unknownCriterionValue = @"foo";
    NSDictionary *unknownCriterionInput = @{
        unknownCriterionKey: unknownCriterionValue,
    };
    NSDictionary *unknownCriterionInput2 = @{
        @".field" : unknownCriterionInput,
    };

    NSString *unknownValueKey = @"INEXISTENT VALUE";
    NSString *unknownValueValue = @"bar";

    NSDictionary *unknownValueInput = @{
        @".field" : @{
            @"eq": @{
                unknownValueKey: unknownValueValue,
            },
        },
    };
    XCTAssertThrowsSpecific([parser parse:unknownCriterionInput dataSource:[WPSPInstallationSource new]], WPSPUnknownCriterionException);
    XCTAssertThrowsSpecific([parser parse:unknownCriterionInput2 dataSource:[WPSPInstallationSource new]], WPSPUnknownCriterionException);
    
    id ast1 = [parserLenientCriterion parse:unknownCriterionInput dataSource:[WPSPInstallationSource new]];
    XCTAssertTrue([ast1 isKindOfClass:WPSPASTUnknownCriterionNode.class]);
    WPSPASTUnknownCriterionNode *checkedAst1 = (WPSPASTUnknownCriterionNode *)ast1;
    XCTAssertEqualObjects(unknownCriterionKey, checkedAst1.key);
    XCTAssertEqualObjects(unknownCriterionValue, checkedAst1.value);

    id ast2 = [parserLenientCriterion parse:unknownCriterionInput2 dataSource:[WPSPInstallationSource new]];
    XCTAssertTrue([ast2 isKindOfClass:WPSPASTUnknownCriterionNode.class]);
    WPSPASTUnknownCriterionNode *checkedAst2 = (WPSPASTUnknownCriterionNode *)ast2;
    XCTAssertEqualObjects(unknownCriterionKey, checkedAst2.key);
    XCTAssertEqualObjects(unknownCriterionValue, checkedAst2.value);
    
    // Ensure being lenient on criterion does not change being lenient on values
    for (WPSPSegmentationDSLParser *p in @[parserLenientCriterion, parser]) {
        XCTAssertThrowsSpecific([p parse:unknownValueInput dataSource:[WPSPInstallationSource new]], WPSPUnknownValueException);
    }
}

- (void)testNoThrowValue {
    // it should not throw on unknown value when configured to
    WPSPDefaultValueNodeParser *defaultValueNodeParser = [WPSPDefaultValueNodeParser new];
    WPSPDefaultCriterionNodeParser *defaultCriterionNodeParser = [WPSPDefaultCriterionNodeParser new];
    WPSPParserConfig *parserConfig = [[WPSPParserConfig alloc]
                                      initWithValueParser:VALUE_NODE_PARSER_BLOCK { return [defaultValueNodeParser parseValueWithContext:context key:key input:input]; }
                                      criterionParser:CRITERION_NODE_PARSER_BLOCK { return [defaultCriterionNodeParser parseCriterionWithContext:context key:key input:input]; }
                                      throwOnUnknownCriterion:YES
                                      throwOnUnknownValue:NO];
    WPSPSegmentationDSLParser *parserLenientCriterion = [[WPSPSegmentationDSLParser alloc] initWithParserConfig:parserConfig];
    
    NSString *unknownCriterionKey = @"INEXISTENT CRITERION";
    NSString *unknownCriterionValue = @"foo";
    NSDictionary *unknownCriterionInput = @{
        unknownCriterionKey: unknownCriterionValue,
    };

    NSString *unknownValueKey = @"INEXISTENT VALUE";
    NSString *unknownValueValue = @"bar";

    NSDictionary *unknownValueInput = @{
        @".field" : @{
            @"eq": @{
                unknownValueKey: unknownValueValue,
            },
        },
    };
    
    // Ensure being lenient on criterion does not change being lenient on values
    for (WPSPSegmentationDSLParser *p in @[parserLenientCriterion, parser]) {
        XCTAssertThrowsSpecific([p parse:unknownCriterionInput dataSource:[WPSPInstallationSource new]], WPSPUnknownCriterionException);
    }

    XCTAssertThrowsSpecific([parser parse:unknownValueInput dataSource:[WPSPInstallationSource new]], WPSPUnknownValueException);

    id ast1 = [parserLenientCriterion parse:unknownValueInput dataSource:[WPSPInstallationSource new]];
    XCTAssertTrue([ast1 isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAst1 = (WPSPEqualityCriterionNode *)ast1;
    XCTAssertTrue([checkedAst1.value isKindOfClass:WPSPASTUnknownValueNode.class]);
    WPSPASTUnknownValueNode *checkedAst1Value = (WPSPASTUnknownValueNode *)checkedAst1.value;
    XCTAssertEqualObjects(unknownValueKey, checkedAst1Value.key);
    XCTAssertEqualObjects(unknownValueValue, checkedAst1Value.value);
}

- (void)testMatchAll {
    // it should parse {} as MatchAllCriterionNode
    XCTAssertTrue([[parser parse:@{} dataSource:[WPSPInstallationSource new]] isKindOfClass:WPSPMatchAllCriterionNode.class]);
}

- (NSNumber *)timeSince1970FromComponents:(NSArray <NSNumber *> *)components {
    static NSCalendar *gregorianCalendar = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        gregorianCalendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    });
    NSDateComponents *dateComponents = [NSDateComponents new];
    dateComponents.year = components[0].integerValue;
    dateComponents.month = components[1].integerValue;
    dateComponents.day = components[2].integerValue;
    dateComponents.hour = components[3].integerValue;
    dateComponents.minute = components[4].integerValue;
    dateComponents.second = components[5].integerValue;
    dateComponents.nanosecond = components[6].integerValue * 1000000;
    NSDate *date = [gregorianCalendar dateFromComponents:dateComponents];
    long long epochMs = date.timeIntervalSince1970 * 1000;
    return [NSNumber numberWithLongLong:epochMs];
}

- (void)testNodeType {
    
    NSArray *testCases = @[
        @[NSNull.null, WPSPNullValueNode.class, NSNull.null],
        @[@YES, WPSPBooleanValueNode.class, NSNull.null],
        @[@NO, WPSPBooleanValueNode.class, NSNull.null],
        @[@0, WPSPNumberValueNode.class, NSNull.null],
        @[[NSNumber numberWithLongLong:LONG_LONG_MAX], WPSPNumberValueNode.class, NSNull.null],
        @[[NSDecimalNumber notANumber], WPSPNumberValueNode.class, NSNull.null],
        @[@"foo", WPSPStringValueNode.class, NSNull.null],
        // Dates
        @[@{ @"date": @1445470140000 }, WPSPDateValueNode.class, @1445470140000],
        @[@{ @"date": @"2020-02-03T04:05:06.007Z" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @3, @4, @5, @6, @7]]],
        @[@{ @"date": @"2020-02-03T04:05:06.007" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @3, @4, @5, @6, @7]]],
        @[@{ @"date": @"2020-02-03T04:05:06" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @3, @4, @5, @6, @0]]],
        @[@{ @"date": @"2020-02-03T04:05" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @3, @4, @5, @0, @0]]],
        @[@{ @"date": @"2020-02-03T04" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @3, @4, @0, @0, @0]]],
        @[@{ @"date": @"2020-02-03" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @3, @0, @0, @0, @0]]],
        @[@{ @"date": @"2020-02" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @2, @1, @0, @0, @0, @0]]],
        @[@{ @"date": @"2020" }, WPSPDateValueNode.class, [self timeSince1970FromComponents:@[@2020, @1, @1, @0, @0, @0, @0]]],
        @[@{ @"date": @"2015-10-21T16:29:00-07:00" }, WPSPDateValueNode.class, @1445470140000],
        // Durations
        @[@{ @"duration": @42 }, WPSPDurationValueNode.class, @42],
        @[@{ @"duration": @"P1W2DT3H4M5.6S" }, WPSPDurationValueNode.class, @(((((7 * 1 + 2) * 24 + 3) * 60 + 4) * 60 + 5.6) * 1000)],
        @[@{ @"duration": @"1.5 ns" }, WPSPDurationValueNode.class, @0.0000015],
        @[@{ @"duration": @"1.5 us" }, WPSPDurationValueNode.class, @0.0015],
        @[@{ @"duration": @"1.5 ms" }, WPSPDurationValueNode.class, @1.5],
        @[@{ @"duration": @"1.5 s" }, WPSPDurationValueNode.class, @1500],
        @[@{ @"duration": @"1.5 m" }, WPSPDurationValueNode.class, @(1500 * 60)],
        @[@{ @"duration": @"1.5 h" }, WPSPDurationValueNode.class, @(1500 * 60 * 60)],
        @[@{ @"duration": @"1.5 d" }, WPSPDurationValueNode.class, @(1500 * 60 * 60 * 24)],
        @[@{ @"duration": @"1.5 w" }, WPSPDurationValueNode.class, @(1500 * 60 * 60 * 24 * 7)],

        // Geo
        @[@{ @"geolocation": @{ @"lat": @0, @"lon": @0 } }, WPSPGeoLocationValueNode.class, [[WPSPGeoLocation alloc] initWithLat:0 lon:0]],
        @[@{ @"geolocation": @"u09tunq" }, WPSPGeoLocationValueNode.class, [[WPSPGeohash parse:@"u09tunq"] toGeoLocation]],
        @[@{ @"geobox": @"u09tunq" }, WPSPGeoBoxValueNode.class, [WPSPGeohash parse:@"u09tunq"]],
        
        @[@{ @"geobox": @{ @"topLeft": @{ @"lat": @2, @"lon": @3 }, @"bottomRight": @{ @"lat": @1, @"lon": @4 } } }, WPSPGeoBoxValueNode.class, [[WPSPGeoBox alloc] initWithTop:2 right:4 bottom:1 left:3]],
        @[@{ @"geobox": @{ @"topRight": @{ @"lat": @2, @"lon": @4 }, @"bottomLeft": @{ @"lat": @1, @"lon": @3 } } }, WPSPGeoBoxValueNode.class, [[WPSPGeoBox alloc] initWithTop:2 right:4 bottom:1 left:3]],
        @[@{ @"geobox": @{ @"top": @2, @"right": @4, @"bottom": @1, @"left": @3 } }, WPSPGeoBoxValueNode.class, [[WPSPGeoBox alloc] initWithTop:2 right:4 bottom:1 left:3]],
        

        @[@{ @"geocircle": @{ @"radius": @1, @"center": @{ @"lat": @2, @"lon": @3 } } }, WPSPGeoCircleValueNode.class, [[WPSPGeoCircle alloc] initWithCenter:[[WPSPGeoLocation alloc] initWithLat:2 lon:3] radiusMeters:1]],
        @[@{ @"geocircle": @{ @"radius": @1, @"center": @"u09tunq" } }, WPSPGeoCircleValueNode.class, [[WPSPGeoCircle alloc] initWithCenter:[WPSPGeohash parse:@"u09tunq"].toGeoLocation radiusMeters:1]],
        @[@{ @"geopolygon": @[ @{ @"lat": @0, @"lon": @1 }, @{ @"lat": @2, @"lon": @3 }, @{ @"lat": @4, @"lon": @5 } ] }, WPSPGeoPolygonValueNode.class, [[WPSPGeoPolygon alloc] initWithPoints:@[[[WPSPGeoLocation alloc] initWithLat:0 lon:1], [[WPSPGeoLocation alloc] initWithLat:2 lon:3], [[WPSPGeoLocation alloc] initWithLat:4 lon:5]]]],
        @[@{ @"geopolygon": @[ @"t", @"u", @"v" ] }, WPSPGeoPolygonValueNode.class, [[WPSPGeoPolygon alloc] initWithPoints:@[[WPSPGeohash parse:@"t"].toGeoLocation, [WPSPGeohash parse:@"u"].toGeoLocation, [WPSPGeohash parse:@"v"].toGeoLocation]]],
    ];
    
    for (NSArray *testCase in testCases) {
        id inputValue = testCase[0];
        id expectedValueNodeClass = testCase[1];
        id expectedValueNodeValue = testCase[2];
        NSDictionary *input = @{
            @".field": @{
                    @"eq": inputValue,
            }
        };

        id ast = [parser parse:input dataSource:[WPSPInstallationSource new]];
        XCTAssertTrue([ast isKindOfClass:WPSPEqualityCriterionNode.class]);
        WPSPEqualityCriterionNode *checkedAst = (WPSPEqualityCriterionNode *)ast;
        XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
        XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPFieldSource.class]);
        WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAst.context.dataSource;
        XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
        XCTAssertTrue([checkedAst.value isKindOfClass:expectedValueNodeClass], @"Should be of type %@, was %@. Input: %@", NSStringFromClass(expectedValueNodeClass), NSStringFromClass(checkedAst.value.class), input);
        id expected = expectedValueNodeValue && expectedValueNodeValue != NSNull.null ? expectedValueNodeValue : inputValue;
        XCTAssertEqualObjects(checkedAst.value.value, expected);
    }
}
@end
