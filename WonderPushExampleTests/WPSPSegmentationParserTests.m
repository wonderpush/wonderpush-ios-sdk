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

@interface AlienDataSource : WPSPDataSource
@end
@implementation AlienDataSource
- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return nil;
}
- (NSString *)name {
    return @"alien";
}
@end

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
        @{@"gt": @0}, // only available with a field data source
        @{ @".field": @{ @"not": @{ @"presence": @{ @"present": @YES } } } }, // only available directly under an installation data source
        @{ @".field": @{ @"not": @{ @"geo": @{ } } } }, // only available directly under an installation data source
        @{ @".field": @{ @"not": @{ @"lastActivityDate": @{ @"gte": @0 } } } }, // only available directly under an installation data source
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

- (void)testParseDate {
    // it should parse {".field":{"eq":{"date":"P1Y"}}}
    NSDictionary *input = @{
        @".field" : @{
            @"eq": @{
                @"date": @"P1Y",
            },
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAst = ast;
    XCTAssertTrue([checkedAst.value isKindOfClass:WPSPRelativeDateValueNode.class]);
    WPSPRelativeDateValueNode *checkedAstValue = (WPSPRelativeDateValueNode *)checkedAst.value;
    XCTAssertEqualObjects(checkedAstValue.duration, [[WPSPISO8601Duration alloc] initWithYears:@1 months:@0 weeks:@0 days:@0 hours:@0 minutes:@0 seconds:@0 positive:YES]);
    

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorianCalendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDateComponents *dateComponents = [NSDateComponents new];
    dateComponents.year = 1;
    NSDate *nextYear = [gregorianCalendar dateByAddingUnit:NSCalendarUnitYear value:1 toDate:[NSDate new] options:0];
    XCTAssertEqualWithAccuracy(checkedAstValue.value.integerValue, (NSInteger)(nextYear.timeIntervalSince1970 * 1000), 500);
}

- (void)testAll {
    // it should parse {".field":{"all":[0,"foo"]}}
    NSDictionary *input = @{
        @".field": @{
            @"all" : @[
                @0,
                @"foo",
            ],
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAllCriterionNode.class]);
    WPSPAllCriterionNode *checkedAst = ast;
    XCTAssertEqual(checkedAst.values.count, 2);

    XCTAssertTrue([checkedAst.values[0] isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedAstValues0 = (WPSPNumberValueNode *)checkedAst.values[0];
    XCTAssertEqual(checkedAstValues0.value, @0);

    XCTAssertTrue([checkedAst.values[1] isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedAstValues1 = (WPSPStringValueNode *)checkedAst.values[1];
    XCTAssertEqual(checkedAstValues1.value, @"foo");
}

- (void)testAny {
    // it should parse {".field":{"any":[0,"foo"]}}
    NSDictionary *input = @{
        @".field": @{
            @"any" : @[
                @0,
                @"foo",
            ],
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAnyCriterionNode.class]);
    WPSPAnyCriterionNode *checkedAst = ast;
    XCTAssertEqual(checkedAst.values.count, 2);

    XCTAssertTrue([checkedAst.values[0] isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedAstValues0 = (WPSPNumberValueNode *)checkedAst.values[0];
    XCTAssertEqual(checkedAstValues0.value, @0);

    XCTAssertTrue([checkedAst.values[1] isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedAstValues1 = (WPSPStringValueNode *)checkedAst.values[1];
    XCTAssertEqual(checkedAstValues1.value, @"foo");
}

- (void)testNot {
    // it should parse {".field":{"not":{"eq":"foo"}}}
    NSDictionary *input = @{
        @".field": @{
            @"not": @{
                @"eq": @"foo",
            },
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPNotCriterionNode.class]);
    WPSPNotCriterionNode *checkedAst = ast;
    XCTAssertTrue([checkedAst.child isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAstChild = (WPSPEqualityCriterionNode *)checkedAst.child;
    XCTAssertTrue([checkedAstChild.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedAstChildDataSource = (WPSPFieldSource *)checkedAstChild.context.dataSource;
    XCTAssertEqualObjects(checkedAstChildDataSource.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild.value isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedAstChildValue = (WPSPStringValueNode *)checkedAstChild.value;
    XCTAssertEqualObjects(checkedAstChildValue.value, @"foo");
}

- (void)testAnd {
    // it should parse {".field":{"and":[{"gt":0},{"lt":1}]}}
    NSDictionary *input = @{
        @".field": @{
            @"and": @[
                @{
                    @"gt": @0,
                },
                @{
                    @"lt": @1,
                },
            ],
        },
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAndCriterionNode.class]);
    WPSPAndCriterionNode *checkedAst = ast;
    XCTAssertEqual(checkedAst.children.count, 2);
    
    XCTAssertTrue([checkedAst.children[0] isKindOfClass:WPSPComparisonCriterionNode.class]);
    WPSPComparisonCriterionNode *checkedAstChild0 = (WPSPComparisonCriterionNode *)checkedAst.children[0];
    XCTAssertTrue([checkedAstChild0.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertEqual(checkedAstChild0.comparator, WPSPComparatorGt);
    XCTAssertTrue([checkedAstChild0.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource0 = (WPSPFieldSource *)checkedAstChild0.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource0.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild0.value isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedValue0 = (WPSPNumberValueNode *)checkedAstChild0.value;
    XCTAssertEqualObjects(checkedValue0.value, @0);

    XCTAssertTrue([checkedAst.children[1] isKindOfClass:WPSPComparisonCriterionNode.class]);
    WPSPComparisonCriterionNode *checkedAstChild1 = (WPSPComparisonCriterionNode *)checkedAst.children[1];
    XCTAssertTrue([checkedAstChild1.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertEqual(checkedAstChild1.comparator, WPSPComparatorLt);
    XCTAssertTrue([checkedAstChild1.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource1 = (WPSPFieldSource *)checkedAstChild1.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource1.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild1.value isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedValue1 = (WPSPNumberValueNode *)checkedAstChild1.value;
    XCTAssertEqualObjects(checkedValue1.value, @1);
}

- (void)testOr {
    // it should parse {".field":{"or":[{"gt":0},{"lt":1}]}}
    NSDictionary *input = @{
        @".field": @{
            @"or": @[
                @{
                    @"gt": @0,
                },
                @{
                    @"lt": @1,
                },
            ],
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPOrCriterionNode.class]);
    WPSPOrCriterionNode *checkedAst = ast;
    XCTAssertEqual(checkedAst.children.count, 2);

    XCTAssertTrue([checkedAst.children[0] isKindOfClass:WPSPComparisonCriterionNode.class]);
    WPSPComparisonCriterionNode *checkedAstChild0 = (WPSPComparisonCriterionNode *)checkedAst.children[0];
    XCTAssertTrue([checkedAstChild0.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertEqual(checkedAstChild0.comparator, WPSPComparatorGt);
    XCTAssertTrue([checkedAstChild0.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource0 = (WPSPFieldSource *)checkedAstChild0.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource0.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild0.value isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedValue0 = (WPSPNumberValueNode *)checkedAstChild0.value;
    XCTAssertEqualObjects(checkedValue0.value, @0);

    XCTAssertTrue([checkedAst.children[1] isKindOfClass:WPSPComparisonCriterionNode.class]);
    WPSPComparisonCriterionNode *checkedAstChild1 = (WPSPComparisonCriterionNode *)checkedAst.children[1];
    XCTAssertTrue([checkedAstChild1.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertEqual(checkedAstChild1.comparator, WPSPComparatorLt);
    XCTAssertTrue([checkedAstChild1.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource1 = (WPSPFieldSource *)checkedAstChild1.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource1.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild1.value isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedValue1 = (WPSPNumberValueNode *)checkedAstChild1.value;
    XCTAssertEqualObjects(checkedValue1.value, @1);

}

- (void)testComparisonOperators {
    // it should parse {".field":{"%s":"foo"}} with %s one of "gt", "lt", "gte", "lte"
    for (NSString *comparatorOp in @[@"gt", @"gte", @"lt", @"lte"]) {
        NSDictionary *input = @{
            @".field": @{
                comparatorOp: @"foo",
            },
        };
        id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
        XCTAssertTrue([ast isKindOfClass:WPSPComparisonCriterionNode.class]);
        WPSPComparisonCriterionNode *checkedAst = ast;
        XCTAssertEqual(checkedAst.comparator, [WPSPComparisonCriterionNode comparatorWithString:comparatorOp]);

        XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
        XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPFieldSource.class]);
        WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAst.context.dataSource;
        XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
        XCTAssertTrue([checkedAst.value isKindOfClass:WPSPStringValueNode.class]);
        WPSPStringValueNode *checkedValue = (WPSPStringValueNode *)checkedAst.value;
        XCTAssertEqualObjects(checkedValue.value, @"foo");
    }
}

- (void)testComparisonRange {
    // it should parse {".field":{"gt":0,"lt":1}}
    NSDictionary *input = @{
        @".field": @{
            @"gt": @0,
            @"lt": @1,
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAndCriterionNode.class]);
    WPSPAndCriterionNode *checkedAst = (WPSPAndCriterionNode *)ast;
    XCTAssertEqual(checkedAst.children.count, 2);

    XCTAssertTrue([checkedAst.children[0] isKindOfClass:WPSPComparisonCriterionNode.class]);
    WPSPComparisonCriterionNode *checkedAstChild0 = (WPSPComparisonCriterionNode *)checkedAst.children[0];
    XCTAssertTrue([checkedAstChild0.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertEqual(checkedAstChild0.comparator, [WPSPComparisonCriterionNode comparatorWithString:@"gt"]);
    XCTAssertTrue([checkedAstChild0.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource0 = (WPSPFieldSource *)checkedAstChild0.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource0.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild0.value isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedValue0 = (WPSPNumberValueNode *)checkedAstChild0.value;
    XCTAssertEqualObjects(checkedValue0.value, @0);

    XCTAssertTrue([checkedAst.children[1] isKindOfClass:WPSPComparisonCriterionNode.class]);
    WPSPComparisonCriterionNode *checkedAstChild1 = (WPSPComparisonCriterionNode *)checkedAst.children[1];
    XCTAssertTrue([checkedAstChild1.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertEqual(checkedAstChild1.comparator, [WPSPComparisonCriterionNode comparatorWithString:@"lt"]);
    XCTAssertTrue([checkedAstChild1.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource1 = (WPSPFieldSource *)checkedAstChild1.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource1.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild1.value isKindOfClass:WPSPNumberValueNode.class]);
    WPSPNumberValueNode *checkedValue1 = (WPSPNumberValueNode *)checkedAstChild1.value;
    XCTAssertEqualObjects(checkedValue1.value, @1);
}

- (void)testPrefix {
    // it should parse {".field":{"prefix":"foo"}}
    NSDictionary *input = @{
        @".field": @{
            @"prefix": @"foo",
        },
    };

    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPPrefixCriterionNode.class]);
    WPSPPrefixCriterionNode *checkedAst = (WPSPPrefixCriterionNode *)ast;
    XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPFieldSource.class]);

    WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAst.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAst.value isKindOfClass:WPSPStringValueNode.class]);
    XCTAssertEqualObjects(checkedAst.value.value, @"foo");
}

- (void)testInsideGeoBox {
    // it should parse {".field":{"inside":{"geobox":"ezs42"}}}
    WPSPGeohash *geohash = [WPSPGeohash parse:@"ezs42"];
    NSDictionary *input = @{
        @".field": @{
            @"inside": @{
                @"geobox": geohash.geohash,
            },
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPInsideCriterionNode.class]);
    WPSPInsideCriterionNode *checkedAst = (WPSPInsideCriterionNode *)ast;

    XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAst.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);

    XCTAssertTrue([checkedAst.value isKindOfClass:WPSPGeoBoxValueNode.class]);
    XCTAssertTrue([checkedAst.value.value isKindOfClass:WPSPGeoBox.class]);
    WPSPGeoBox *checkedAstValueValue = (WPSPGeoBox *)checkedAst.value.value;
    XCTAssertEqual(checkedAstValueValue.top, geohash.top);
    XCTAssertEqual(checkedAstValueValue.right, geohash.right);
    XCTAssertEqual(checkedAstValueValue.bottom, geohash.bottom);
    XCTAssertEqual(checkedAstValueValue.left, geohash.left);
}

- (void)testInsideGeoCircle {
    // it should parse {".field":{"inside":{"geocircle":{radius:1,center:{"lat":1,"lon":2}}}}}
    NSDictionary *input = @{
        @".field": @{
            @"inside": @{
                @"geocircle": @{
                    @"radius": @1,
                    @"center": @{
                        @"lat": @1,
                        @"lon": @2,
                    },
                },
            },
        },
    };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPInsideCriterionNode.class]);
    WPSPInsideCriterionNode *checkedAst = (WPSPInsideCriterionNode *)ast;
    XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAst.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAst.value isKindOfClass:WPSPGeoCircleValueNode.class]);
    XCTAssertTrue([checkedAst.value.value isKindOfClass:WPSPGeoCircle.class]);
    WPSPGeoCircle *checkedAstValueValue = (WPSPGeoCircle *)checkedAst.value.value;
    XCTAssertEqual(checkedAstValueValue.radiusMeters, 1);
    XCTAssertEqual(checkedAstValueValue.center.lat, 1);
    XCTAssertEqual(checkedAstValueValue.center.lon, 2);
}

- (void)testInsideGeoPolygon {
    // it should parse {".field":{"inside":{"geopolygon":["t",{"lat":0,"lon":0},"v"]}}}
    NSDictionary *input = @{
               @".field": @{
                   @"inside": @{
                       @"geopolygon": @[
                           @"t",
                           @{
                               @"lat": @0,
                               @"lon": @0,
                           },
                           @"v",
                       ],
                   },
               },
           };
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPInsideCriterionNode.class]);
    WPSPInsideCriterionNode *checkedAst = (WPSPInsideCriterionNode *)ast;
    XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAst.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAst.value isKindOfClass:WPSPGeoPolygonValueNode.class]);
    XCTAssertTrue([checkedAst.value.value isKindOfClass:WPSPGeoPolygon.class]);
    WPSPGeoPolygon *checkedAstValueValue = (WPSPGeoPolygon *)checkedAst.value.value;
    XCTAssertEqual(checkedAstValueValue.points.count, 3);
    XCTAssertEqualObjects(checkedAstValueValue.points[0], [WPSPGeohash parse:@"t"].toGeoLocation);
    XCTAssertEqual(checkedAstValueValue.points[1].lat, 0);
    XCTAssertEqual(checkedAstValueValue.points[1].lon, 0);
    XCTAssertEqualObjects(checkedAstValueValue.points[2], [WPSPGeohash parse:@"v"].toGeoLocation);
}

- (void)testLastActivityThrow {
    // it should parse {"lastActivityDate":{}}
    NSDictionary *input = @{
        @"lastActivityDate": @{},
    };
    // Missing data comparison. We've moved into comparing some field but we're not giving any comparison to perform.
    XCTAssertThrowsSpecific([parser parse:input dataSource:[WPSPInstallationSource new]], WPSPBadInputException);
}

- (void)testLastActivity {
    // it should parse {"lastActivityDate":{"gte":{"date":"-P1D"}}}
    NSDictionary *input = @{
       @"lastActivityDate": @{
           @"gte": @{
               @"date": @"-P1D",
            },
        },
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPLastActivityDateCriterionNode.class]);
    WPSPLastActivityDateCriterionNode *checkedAst = ast;
    XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAst.dateComparison.context.dataSource isKindOfClass:WPSPLastActivityDateSource.class]);
    XCTAssertTrue([checkedAst.dateComparison isKindOfClass:WPSPComparisonCriterionNode.class]);
}

- (void)testPresence {
    NSArray *testCases = @[
        @[NSNull.null,  NSNull.null, NSNull.null,],
        @[@YES,         NSNull.null, NSNull.null,],
        @[@NO,          NSNull.null, NSNull.null,],
        @[@YES,         @{ @"gt": @0 }, NSNull.null,],
        @[@YES,         NSNull.null, @{ @"gt": @0 },],
        @[@YES,         @{ @"gt": @0, @"lt": @0 }, NSNull.null,],
        @[@YES,         NSNull.null, @{ @"gt": @0, @"lt": @0 },],
        @[@YES,         @{ @"gt": @0, @"lt": @0 }, @{ @"gt": @0, @"lt": @0 },],
    ];
    for (NSArray *testCase in testCases) {
        NSMutableDictionary *presence = [NSMutableDictionary new];
        NSNumber *present = testCase[0];
        id sinceDate = testCase[1];
        id elapsedTime = testCase[2];
        NSDictionary *input = @{
            @"presence": presence,
        };
        if (testCase[0] != NSNull.null) presence[@"present"] = testCase[0];
        else {
            XCTAssertThrowsSpecific([parser parse:input dataSource:[WPSPInstallationSource new]], WPSPBadInputException);
            continue;
        }
        if (sinceDate != NSNull.null) presence[@"sinceDate"] = sinceDate;
        if (elapsedTime != NSNull.null) presence[@"elapsedTime"] = elapsedTime;


        id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
        XCTAssertTrue([ast isKindOfClass:WPSPPresenceCriterionNode.class]);
        WPSPPresenceCriterionNode *checkedAst = ast;
        XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
        XCTAssertEqual(checkedAst.present, present.boolValue);
        
        if (sinceDate == NSNull.null) {
            XCTAssertNil(checkedAst.sinceDateComparison);
        } else {
            if ([sinceDate count] == 1) {
                XCTAssertTrue([checkedAst.sinceDateComparison isKindOfClass:WPSPComparisonCriterionNode.class]);
                WPSPComparisonCriterionNode *checkedComparison = (WPSPComparisonCriterionNode *)checkedAst.sinceDateComparison;
                XCTAssertTrue([checkedComparison.context.dataSource isKindOfClass:WPSPPresenceSinceDateSource.class]);
                WPSPPresenceSinceDateSource *checkedComparisonContextDataSource = (WPSPPresenceSinceDateSource *)checkedComparison.context.dataSource;
                XCTAssertEqual(checkedComparisonContextDataSource.present, present.boolValue);
            } else {
                XCTAssertTrue([checkedAst.sinceDateComparison isKindOfClass:WPSPAndCriterionNode.class]);
                XCTAssertEqual(((WPSPAndCriterionNode *)checkedAst.sinceDateComparison).children.count, [sinceDate count]);
                for (id child in ((WPSPAndCriterionNode *)checkedAst.sinceDateComparison).children) {
                    XCTAssertTrue([child isKindOfClass:WPSPComparisonCriterionNode.class]);
                    WPSPComparisonCriterionNode *checkedComparison = (WPSPComparisonCriterionNode *)child;
                    XCTAssertTrue([checkedComparison.context.dataSource isKindOfClass:WPSPPresenceSinceDateSource.class]);
                    WPSPPresenceSinceDateSource *checkedComparisonContextDataSource = (WPSPPresenceSinceDateSource *)checkedComparison.context.dataSource;
                    XCTAssertEqual(checkedComparisonContextDataSource.present, present.boolValue);
                }
            }
        }
        
        if (elapsedTime == NSNull.null) {
            XCTAssertNil(checkedAst.elapsedTimeComparison);
        } else {
            if ([elapsedTime count] == 1) {
                XCTAssertTrue([checkedAst.elapsedTimeComparison isKindOfClass:WPSPComparisonCriterionNode.class]);
                WPSPComparisonCriterionNode *checkedComparison = (WPSPComparisonCriterionNode *)checkedAst.elapsedTimeComparison;
                XCTAssertTrue([checkedComparison.context.dataSource isKindOfClass:WPSPPresenceElapsedTimeSource.class]);
                WPSPPresenceElapsedTimeSource *checkedComparisonContextDataSource = (WPSPPresenceElapsedTimeSource *)checkedComparison.context.dataSource;
                XCTAssertEqual(checkedComparisonContextDataSource.present, present.boolValue);
            } else {
                XCTAssertTrue([checkedAst.elapsedTimeComparison isKindOfClass:WPSPAndCriterionNode.class]);
                XCTAssertEqual(((WPSPAndCriterionNode *)checkedAst.elapsedTimeComparison).children.count, [elapsedTime count]);
                for (id child in ((WPSPAndCriterionNode *)checkedAst.elapsedTimeComparison).children) {
                    XCTAssertTrue([child isKindOfClass:WPSPComparisonCriterionNode.class]);
                    WPSPComparisonCriterionNode *checkedComparison = (WPSPComparisonCriterionNode *)child;
                    XCTAssertTrue([checkedComparison.context.dataSource isKindOfClass:WPSPPresenceElapsedTimeSource.class]);
                    WPSPPresenceElapsedTimeSource *checkedComparisonContextDataSource = (WPSPPresenceElapsedTimeSource *)checkedComparison.context.dataSource;
                    XCTAssertEqual(checkedComparisonContextDataSource.present, present.boolValue);
                }
            }
        }
    }
}

- (void)testPresentSinceDateOr {
    // it should parse {"presence":{"present":true,"sinceDate":{"or":[{"gt":0,"lt":1},{"gt":10,"lt":11}]}}}
    NSDictionary *input = @{
        @"presence": @{
            @"present": @YES,
            @"sinceDate": @{
                @"or": @[
                    @{
                        @"gt": @0,
                        @"lt": @1,
                    },
                    @{
                        @"gt": @10,
                        @"lt": @11,
                    },
                ],
            },
        },
    };
    XCTAssertTrue([[parser parse:input dataSource:WPSPInstallationSource.new] isKindOfClass:WPSPPresenceCriterionNode.class]);
}

- (void)testPresenceWrongDataSource {
    // it should not parse {"%s":{"presence":{"present":true}}} where %s is "user" or "event"
    for (NSString *objectType in @[@"user", @"event"]) {
        NSDictionary *input = @{
            objectType: @{
                    @"presence": @{
                            @"present": @YES,
                    }
            }
        };
        XCTAssertThrowsSpecific([parser parse:input dataSource:WPSPInstallationSource.new], WPSPBadInputException);
    }
}

- (void)testInside {
    // it should parse {"geo":{"location":%p,"date":%p}}
    NSArray *testCases = @[
        @[NSNull.null, NSNull.null,],
        @[@{ @"inside": @{ @"geobox": @"u" } }, NSNull.null],
        @[NSNull.null, @{ @"gt": @{ @"date": @"-PT1H" } }],
        @[@{ @"inside": @{ @"geobox": @"u" } }, @{ @"gt": @{ @"date": @"-PT1H" } }],
    ];
    
    for (NSArray *testCase in testCases) {
        NSMutableDictionary *geoDictionary = [NSMutableDictionary new];
        NSDictionary *input = @{
            @"geo" : geoDictionary,
        };
        id location = testCase[0];
        id date = testCase[1];
        if (location != NSNull.null) geoDictionary[@"location"] = location;
        if (date != NSNull.null) geoDictionary[@"date"] = date;
        id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
        XCTAssertTrue([ast isKindOfClass:WPSPGeoCriterionNode.class]);
        WPSPGeoCriterionNode *checkedAst = ast;
        XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
        if (location == NSNull.null) {
            XCTAssertNil(checkedAst.locationComparison);
        } else {
            XCTAssertTrue([checkedAst.locationComparison isKindOfClass:WPSPInsideCriterionNode.class]);
            WPSPInsideCriterionNode *checkedComparison = (WPSPInsideCriterionNode *)checkedAst.locationComparison;
            XCTAssertTrue([checkedComparison.context.dataSource isKindOfClass:WPSPGeoLocationSource.class]);
        }
        if (date == NSNull.null) {
            XCTAssertNil(checkedAst.dateComparison);
        } else {
            XCTAssertTrue([checkedAst.dateComparison isKindOfClass:WPSPComparisonCriterionNode.class]);
            WPSPComparisonCriterionNode *checkedComparison = (WPSPComparisonCriterionNode *)checkedAst.dateComparison;
            XCTAssertTrue([checkedComparison.context.dataSource isKindOfClass:WPSPGeoDateSource.class]);
        }

    }
}
- (void)testSimpleGeo {
    // it should parse {"geo":{}}
    NSDictionary *input = @{
        @"geo": @{},
    };
    XCTAssertTrue([[parser parse:input dataSource:WPSPInstallationSource.new] isKindOfClass:WPSPGeoCriterionNode.class]);

}

- (void)testComplexGeo {
    NSDictionary *input = @{
        @"geo": @{
            @"location": @{
                @"and": @[
                    @{
                        @"inside": @{
                            @"geobox": @"u",
                        },
                    },
                    @{
                        @"inside": @{
                            @"geocircle": @{
                                @"center": @"u",
                                @"radius": @1,
                            },
                        },
                    },
                ],
            },
            @"date": @{
                @"or": @[
                    @{
                        @"gt": @1,
                    },
                    @{
                        @"lt": @0,
                    },
                ],
            },
        },
    };
    XCTAssertTrue([[parser parse:input dataSource:WPSPInstallationSource.new] isKindOfClass:WPSPGeoCriterionNode.class]);
}

- (void) testGeoWrongDataSource {
    // it should not parse {"%s":{"geo":{}}} where %s is "user" or "event"
    for (NSString *objectType in @[@"user", @"event"]) {
        NSDictionary *input = @{
            objectType: @{
                    @"geo": @{}
            }
        };
        XCTAssertThrowsSpecific([parser parse:input dataSource:WPSPInstallationSource.new], WPSPBadInputException);
    }

}

- (void) testSubscriptionStatus {
    for (NSString *status in @[@"optIn", @"optOut", @"softOptOut"]) {
        NSDictionary *input = @{
            @"subscriptionStatus": status,
        };
        
        id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
        XCTAssertTrue([ast isKindOfClass:WPSPSubscriptionStatusCriterionNode.class]);

        WPSPSubscriptionStatusCriterionNode *checkedAst = ast;
        XCTAssertEqual(checkedAst.subscriptionStatus, [WPSPSubscriptionStatusCriterionNode subscriptionStatusWithString:status]);
    }
}

- (void) testBadSubscriptionStatus {
    NSArray *testCases = @[
        @{ @"subscriptionStatus": @"foo" },
        @{ @"event": @{ @"subscriptionStatus": @"optIn" } },
    ];
    for (NSDictionary *input in testCases) {
        XCTAssertThrowsSpecific([parser parse:input dataSource:WPSPInstallationSource.new], WPSPBadInputException);
        
    }
}

- (void) testFieldSources {
    // it should parse {"%s":{".field":{"eq":"foo"}}} from a %o context (#%#)
    NSArray *testCases = @[
        @[@"user",        WPSPUserSource.new,         @NO,  WPSPUserSource.class,          WPSPUserSource.class],
        @[@"user",        WPSPInstallationSource.new, @YES, WPSPUserSource.class,          WPSPUserSource.class],
        @[@"user",        WPSPEventSource.new,        @YES, WPSPInstallationSource.class,  WPSPUserSource.class],
        @[@"installation",WPSPUserSource.new,         @YES, WPSPInstallationSource.class,  WPSPInstallationSource.class],
        @[@"installation",WPSPInstallationSource.new, @NO,  WPSPInstallationSource.class,  WPSPInstallationSource.class],
        @[@"installation",WPSPEventSource.new,        @YES, WPSPInstallationSource.class,  WPSPInstallationSource.class],
        @[@"event",       WPSPUserSource.new,         @YES, WPSPInstallationSource.class,  WPSPEventSource.class],
        @[@"event",       WPSPInstallationSource.new, @YES, WPSPEventSource.class,         WPSPEventSource.class],
        @[@"event",       WPSPEventSource.new,        @NO,  WPSPEventSource.class,         WPSPEventSource.class],
    ];
    
    for (NSArray *testCase in testCases) {
        NSString *joinType = testCase[0];
        WPSPDataSource *startDataSource = testCase[1];
        BOOL expectedsJoinCriterion = [testCase[2] boolValue];
        Class expectedDataSource = testCase[3];
        Class expectedChildDataSource = testCase[4];
        
        
        NSDictionary *input = @{
            joinType: @{
                @".field": @{
                    @"eq": @"foo",
                },
            },
        };
        if (expectedDataSource == NSNull.null) {
            XCTAssertThrowsSpecific([parser parse:input dataSource:startDataSource], WPSPBadInputException);
            continue;
        }
        
        id ast = [parser parse:input dataSource:startDataSource];
        if (!expectedsJoinCriterion) {
            XCTAssertTrue([ast isKindOfClass:WPSPASTCriterionNode.class]);
            WPSPASTCriterionNode *checkedAst = ast;
            XCTAssertTrue([checkedAst.context.dataSource.rootDataSource isKindOfClass:expectedDataSource]);
        } else {
            XCTAssertTrue([ast isKindOfClass:WPSPJoinCriterionNode.class]);
            WPSPJoinCriterionNode *checkedAst = ast;
            XCTAssertNotNil(checkedAst.context.parentContext);
            XCTAssertEqual(checkedAst.context.parentContext.dataSource, startDataSource);
            XCTAssertTrue([checkedAst.context.dataSource isKindOfClass:expectedDataSource]);
            XCTAssertTrue([checkedAst.child.context.dataSource.rootDataSource isKindOfClass:expectedChildDataSource]);
        }
    }
}

- (void)testAlienDataSource {
    // it should refuse %j on alien data source
    NSArray *testCases = @[
        @[@{@"user": @{} }],
        @[@{@"installation": @{} }],
        @[@{@"event": @{} }],
        @[@{@"lastActivityDate": @{@"gte": @0 } }],
        @[@{@"presence": @{} }],
        @[@{@"geo": @{} }],
    ];
    for (id input in testCases) {
        AlienDataSource *startDataSource = [[AlienDataSource alloc] initWithParent:nil];
        XCTAssertThrowsSpecific([parser parse:input dataSource:startDataSource], WPSPBadInputException);
    }
}

- (void)testRewind {
    // it should rewind field path for {".foo":{"installation":{".bar":{"eq":"bar"}}}}
    NSDictionary *input = @{
        @".foo": @{
           @"eq": @"foo",
            @"installation": @{
                @".bar": @{
                   @"eq": @"bar",
                },
            },
        }
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAndCriterionNode.class]);
    WPSPAndCriterionNode *checkedAst = (WPSPAndCriterionNode *)ast;
    XCTAssertEqual(checkedAst.children.count, 2);
    XCTAssertTrue([checkedAst.children[0] isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAstChild0 = (WPSPEqualityCriterionNode *)checkedAst.children[0];
    XCTAssertTrue([checkedAstChild0.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAstChild0.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource0 = (WPSPFieldSource *)checkedAstChild0.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource0.path.parts, @[@"foo"]);
    XCTAssertTrue([checkedAstChild0.value isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedValue0 = (WPSPStringValueNode *)checkedAstChild0.value;
    XCTAssertEqualObjects(checkedValue0.value, @"foo");
    XCTAssertTrue([checkedAst.children[1] isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAstChild1 = (WPSPEqualityCriterionNode *)checkedAst.children[1];
    XCTAssertTrue([checkedAstChild1.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAstChild1.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource1 = (WPSPFieldSource *)checkedAstChild1.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource1.path.parts, @[@"bar"]);
    XCTAssertTrue([checkedAstChild1.value isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedValue1 = (WPSPStringValueNode *)checkedAstChild1.value;
    XCTAssertEqualObjects(checkedValue1.value, @"bar");
}

- (void)testNotEqual {
    // it should parse {"not":{".field":{"eq":"foo"}}}
    NSDictionary *input = @{
        @"not": @{
            @".field": @{
               @"eq": @"foo",
            },
        },
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPNotCriterionNode.class]);
    WPSPNotCriterionNode *checkedAst = (WPSPNotCriterionNode *)ast;
    XCTAssertTrue([checkedAst.child isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAstChild = (WPSPEqualityCriterionNode *)checkedAst.child;
    XCTAssertTrue([checkedAstChild.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAstChild.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAstChild.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild.value isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedValue = (WPSPStringValueNode *)checkedAstChild.value;
    XCTAssertEqualObjects(checkedValue.value, @"foo");
}

- (void)testAndEqual {
    // it should parse {"and":[{".field":{"eq":"foo"}},{".field":{"eq":"bar"}}]}
    NSDictionary *input = @{
        @"and": @[
            @{ @".field": @{@"eq": @"foo" } },
            @{ @".field": @{@"eq": @"bar" } },
        ],
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAndCriterionNode.class]);
    WPSPAndCriterionNode *checkedAst = (WPSPAndCriterionNode *)ast;
    XCTAssertEqual(checkedAst.children.count, 2);
    
    XCTAssertTrue([checkedAst.children[0] isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAstChild0 = (WPSPEqualityCriterionNode *)checkedAst.children[0];
    XCTAssertTrue([checkedAstChild0.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAstChild0.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource0 = (WPSPFieldSource *)checkedAstChild0.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource0.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild0.value isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedValue0 = (WPSPStringValueNode *)checkedAstChild0.value;
    XCTAssertEqualObjects(checkedValue0.value, @"foo");

    XCTAssertTrue([checkedAst.children[1] isKindOfClass:WPSPEqualityCriterionNode.class]);
    WPSPEqualityCriterionNode *checkedAstChild1 = (WPSPEqualityCriterionNode *)checkedAst.children[1];
    XCTAssertTrue([checkedAstChild1.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
    XCTAssertTrue([checkedAstChild1.context.dataSource isKindOfClass:WPSPFieldSource.class]);
    WPSPFieldSource *checkedDataSource1 = (WPSPFieldSource *)checkedAstChild1.context.dataSource;
    XCTAssertEqualObjects(checkedDataSource1.path.parts, @[@"field"]);
    XCTAssertTrue([checkedAstChild1.value isKindOfClass:WPSPStringValueNode.class]);
    WPSPStringValueNode *checkedValue1 = (WPSPStringValueNode *)checkedAstChild1.value;
    XCTAssertEqualObjects(checkedValue1.value, @"bar");
}

- (void)testAndMultipleFields {
    // it should parse {".fieldFoo":{"eq":"foo"},".fieldBar":{"eq":"bar"}}
    NSDictionary *input = @{
        @".fieldFoo": @{@"eq": @"foo" },
        @".fieldBar": @{@"eq": @"bar" },
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPAndCriterionNode.class]);
    WPSPAndCriterionNode *checkedAst = (WPSPAndCriterionNode *)ast;
    XCTAssertEqual(checkedAst.children.count, 2);
    
    // We can't make an assumption on the order of the keys in a dictionary in objective-c
    for (NSInteger i = 0; i < 2; i++) {
        XCTAssertTrue([checkedAst.children[i] isKindOfClass:WPSPEqualityCriterionNode.class]);
        WPSPEqualityCriterionNode *checkedAstChild = (WPSPEqualityCriterionNode *)checkedAst.children[i];
        XCTAssertTrue([checkedAstChild.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
        XCTAssertTrue([checkedAstChild.context.dataSource isKindOfClass:WPSPFieldSource.class]);
        WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAstChild.context.dataSource;
        XCTAssertTrue(
                      [checkedDataSource.path.parts isEqualToArray:@[@"fieldBar"]]
                      || [checkedDataSource.path.parts isEqualToArray:@[@"fieldFoo"]]
                      );
        BOOL isFoo = [checkedDataSource.path.parts isEqualToArray:@[@"fieldFoo"]];
        XCTAssertTrue([checkedAstChild.value isKindOfClass:WPSPStringValueNode.class]);
        WPSPStringValueNode *checkedValue = (WPSPStringValueNode *)checkedAstChild.value;
        XCTAssertEqualObjects(checkedValue.value, isFoo ? @"foo" : @"bar");
    }
}
- (void)testOrMultipleFields {
    // it should parse {"or":[{".field":{"eq":"foo"}},{".field":{"eq":"bar"}}]}
    NSDictionary *input = @{
        @"or": @[
            @{ @".field": @{@"eq": @"foo" } },
            @{ @".field": @{@"eq": @"bar" } },
        ],
    };
    
    id ast = [parser parse:input dataSource:WPSPInstallationSource.new];
    XCTAssertTrue([ast isKindOfClass:WPSPOrCriterionNode.class]);
    WPSPOrCriterionNode *checkedAst = (WPSPOrCriterionNode *)ast;
    XCTAssertEqual(checkedAst.children.count, 2);
    
    // We can't make an assumption on the order of the keys in a dictionary in objective-c
    for (NSInteger i = 0; i < 2; i++) {
        XCTAssertTrue([checkedAst.children[i] isKindOfClass:WPSPEqualityCriterionNode.class]);
        WPSPEqualityCriterionNode *checkedAstChild = (WPSPEqualityCriterionNode *)checkedAst.children[i];
        XCTAssertTrue([checkedAstChild.context.dataSource.rootDataSource isKindOfClass:WPSPInstallationSource.class]);
        XCTAssertTrue([checkedAstChild.context.dataSource isKindOfClass:WPSPFieldSource.class]);
        WPSPFieldSource *checkedDataSource = (WPSPFieldSource *)checkedAstChild.context.dataSource;
        XCTAssertEqualObjects(checkedDataSource.path.parts, @[@"field"]);
        XCTAssertTrue([checkedAstChild.value isKindOfClass:WPSPStringValueNode.class]);
        WPSPStringValueNode *checkedValue = (WPSPStringValueNode *)checkedAstChild.value;
        XCTAssertTrue(
                      [checkedValue.value isEqualToString:@"foo"]
                      || [checkedValue.value isEqualToString:@"bar"]
                      );
    }
}


@end
