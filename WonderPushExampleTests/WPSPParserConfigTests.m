//
//  WPSPParserConfigTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 07/07/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPParserConfig.h"
#import "WPSPConfigurableCriterionNodeParser.h"
#import "WPSPSegmentationDSLParser.h"
#import "WPSPDefaultValueNodeParser.h"
#import "WPSPDefaultCriterionNodeParser.h"

@interface WPSPParserConfigTests : XCTestCase

@end

@implementation WPSPParserConfigTests

- (void)testRegisterCriterionTwice {
    // it should forbid registering twice a parser with same name
    WPSPConfigurableCriterionNodeParser *ccnp = [WPSPConfigurableCriterionNodeParser new];
    [ccnp registerExactNameParserWithKey:@"foo" parser:CRITERION_NODE_PARSER_BLOCK { return nil; }];
    XCTAssertThrows([ccnp registerExactNameParserWithKey:@"foo" parser:CRITERION_NODE_PARSER_BLOCK { return nil; }]);
}

- (void)testCriterionExactDynamic {
    // it should return parse known nodes using dynamic name after known names and null on unknown nodes
    WPSPConfigurableCriterionNodeParser *ccnp = [WPSPConfigurableCriterionNodeParser new];
    [ccnp registerExactNameParserWithKey:@"known"
                                  parser:CRITERION_NODE_PARSER_BLOCK {
        return [[WPSPAndCriterionNode alloc] initWithContext:context children:@[]];
    }];
    
    [ccnp registerDynamicNameParser:CRITERION_NODE_PARSER_BLOCK {
        if ([key hasPrefix:@"k"]) return [[WPSPOrCriterionNode alloc] initWithContext:context children:@[]];
        return nil;
    }];

    WPSPDefaultValueNodeParser *defaultValueNodeParser = [WPSPDefaultValueNodeParser new];
    WPSPParserConfig *parserConfig = [[WPSPParserConfig alloc]
                                      initWithValueParser:VALUE_NODE_PARSER_BLOCK { return [defaultValueNodeParser parseValueWithContext:context key:key input:input]; }
                                      criterionParser:CRITERION_NODE_PARSER_BLOCK { return [ccnp parseCriterionWithContext:context key:key input:input]; }
                                      throwOnUnknownCriterion:NO
                                      throwOnUnknownValue:YES];
    WPSPSegmentationDSLParser *parser = [[WPSPSegmentationDSLParser alloc] initWithParserConfig:parserConfig];

    WPSPParsingContext *context = [[WPSPParsingContext alloc] initWithParser:parser parentContext:nil dataSource:[WPSPInstallationSource new]];
    XCTAssertTrue([[ccnp parseCriterionWithContext:context key:@"known" input:@"stuff"] isKindOfClass:WPSPAndCriterionNode.class]);
    XCTAssertTrue([[ccnp parseCriterionWithContext:context key:@"kewl" input:@"stuff"] isKindOfClass:WPSPOrCriterionNode.class]);
    XCTAssertTrue([[ccnp parseCriterionWithContext:context key:@"krown" input:@"stuff"] isKindOfClass:WPSPOrCriterionNode.class]);
    XCTAssertNil([ccnp parseCriterionWithContext:context key:@"unknown" input:@"stuff"]);
}

- (void)testRegisterValueTwice {
    // it should forbid registering twice a parser with same name
    WPSPConfigurableValueNodeParser *ccnp = [WPSPConfigurableValueNodeParser new];
    [ccnp registerExactNameParserWithKey:@"foo" parser:VALUE_NODE_PARSER_BLOCK { return nil; }];
    XCTAssertThrows([ccnp registerExactNameParserWithKey:@"foo" parser:VALUE_NODE_PARSER_BLOCK { return nil; }]);
}

- (void)testValueExactDynamic {
    // it should return parse known nodes using dynamic name after known names and null on unknown nodes
    WPSPConfigurableValueNodeParser *cvnp = [WPSPConfigurableValueNodeParser new];
    [cvnp registerExactNameParserWithKey:@"known"
                                  parser:VALUE_NODE_PARSER_BLOCK {
        return [[WPSPStringValueNode alloc] initWithContext:context value:@""];
    }];
    
    [cvnp registerDynamicNameParser:VALUE_NODE_PARSER_BLOCK {
        if ([key hasPrefix:@"k"]) return [[WPSPNumberValueNode alloc] initWithContext:context value:@0];
        return nil;
    }];

    WPSPDefaultCriterionNodeParser *defaultCriterionNodeParser = [WPSPDefaultCriterionNodeParser new];
    WPSPParserConfig *parserConfig = [[WPSPParserConfig alloc]
                                      initWithValueParser:VALUE_NODE_PARSER_BLOCK { return [cvnp parseValueWithContext:context key:key input:input]; }
                                      criterionParser:CRITERION_NODE_PARSER_BLOCK { return [defaultCriterionNodeParser parseCriterionWithContext:context key:key input:input]; }
                                      throwOnUnknownCriterion:NO
                                      throwOnUnknownValue:YES];
    WPSPSegmentationDSLParser *parser = [[WPSPSegmentationDSLParser alloc] initWithParserConfig:parserConfig];

    WPSPParsingContext *context = [[WPSPParsingContext alloc] initWithParser:parser parentContext:nil dataSource:[WPSPInstallationSource new]];
    XCTAssertTrue([[cvnp parseValueWithContext:context key:@"known" input:@"stuff"] isKindOfClass:WPSPStringValueNode.class]);
    XCTAssertTrue([[cvnp parseValueWithContext:context key:@"kewl" input:@"stuff"] isKindOfClass:WPSPNumberValueNode.class]);
    XCTAssertTrue([[cvnp parseValueWithContext:context key:@"krown" input:@"stuff"] isKindOfClass:WPSPNumberValueNode.class]);
    XCTAssertNil([cvnp parseValueWithContext:context key:@"unknown" input:@"stuff"]);
}
@end
