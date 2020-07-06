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

    XCTAssertThrowsSpecific([parser parse:@{@".field": @{@"gloubiboulga": @"toto"}} dataSource:[WPSPInstallationSource new]], WPSPUnknownCriterionException, @"unknown criterion: gloubiboulga");
}
@end
