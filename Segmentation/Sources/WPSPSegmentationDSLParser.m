//
//  WPSegmentationDSLParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPSegmentationDSLParser.h"
#import "WPSPExceptions.h"
#import "WPSPMatchAllCriterionNode.h"
#import "WPSPAndCriterionNode.h"
#import "WPSPASTUnknownCriterionNode.h"
#import "WPJsonUtil.h"
#import "WPSPDefaultValueNodeParser.h"
#import "WPSPDefaultCriterionNodeParser.h"


@implementation WPSPSegmentationDSLParser

+ (instancetype)defaultParser {
    static dispatch_once_t onceToken;
    static WPSPSegmentationDSLParser *rtn = nil;
    static WPSPDefaultValueNodeParser *defaultValueNodeParser = nil;
    static WPSPDefaultCriterionNodeParser *defaultCriterionNodeParser = nil;
    dispatch_once(&onceToken, ^{
        defaultValueNodeParser = [WPSPDefaultValueNodeParser new];
        defaultCriterionNodeParser = [WPSPDefaultCriterionNodeParser new];
        WPSPParserConfig *parserConfig = [[WPSPParserConfig alloc]
                                          initWithValueParser:VALUE_NODE_PARSER_BLOCK(return [defaultValueNodeParser parseValueWithContext:context key:key input:input];)
                                          criterionParser:CRITERION_NODE_PARSER_BLOCK(return [defaultCriterionNodeParser parseCriterionWithContext:context key:key input:input];)
                                          throwOnUnknownCriterion:NO
                                          throwOnUnknownValue:NO];
        rtn = [[WPSPSegmentationDSLParser alloc] initWithParserConfig:parserConfig];
    });
    return rtn;
}

+ (instancetype)defaultThrowingParser {
    static dispatch_once_t onceToken;
    static WPSPSegmentationDSLParser *rtn = nil;
    static WPSPDefaultValueNodeParser *defaultValueNodeParser = nil;
    static WPSPDefaultCriterionNodeParser *defaultCriterionNodeParser = nil;
    dispatch_once(&onceToken, ^{
        defaultValueNodeParser = [WPSPDefaultValueNodeParser new];
        defaultCriterionNodeParser = [WPSPDefaultCriterionNodeParser new];
        WPSPParserConfig *parserConfig = [[WPSPParserConfig alloc]
                                          initWithValueParser:VALUE_NODE_PARSER_BLOCK(return [defaultValueNodeParser parseValueWithContext:context key:key input:input];)
                                          criterionParser:CRITERION_NODE_PARSER_BLOCK(return [defaultCriterionNodeParser parseCriterionWithContext:context key:key input:input];)
                                          throwOnUnknownCriterion:YES
                                          throwOnUnknownValue:YES];
        rtn = [[WPSPSegmentationDSLParser alloc] initWithParserConfig:parserConfig];
    });
    return rtn;
}

- (instancetype)initWithParserConfig:(WPSPParserConfig *)parserConfig {
    if (self = [super init]) {
        _parserConfig = parserConfig;
    }
    return self;
}

- (WPSPASTCriterionNode *)parse:(NSDictionary *)input dataSource:(WPSPDataSource *)dataSource {
    WPSPParsingContext *ctx = [[WPSPParsingContext alloc] initWithParser:self parentContext:nil dataSource:dataSource];
    return [self parseCriterionWithContext:ctx input:input];
}

- (WPSPASTCriterionNode *)parseCriterionWithContext:(WPSPParsingContext *)context input:(NSDictionary *)input {
    // TODO: code me
    if (!input) {
        @throw [WPSPBadInputException new]; // Expects an object
    }
    if (input.count == 0) {
        if (context.dataSource.rootDataSource != context.dataSource) {
            @throw [WPSPBadInputException new]; // Missing data criterion
        }
        return [[WPSPMatchAllCriterionNode alloc] initWithContext:context];
    }
    if (input.count > 1) {
        NSMutableArray<WPSPASTCriterionNode *> *children = [NSMutableArray new];
        for (NSString *key in input.allKeys) {
            [children addObject:[self parseCriterionWithContext:context input:@{
                key: input[key]
            }]];
        }
        return [[WPSPAndCriterionNode alloc] initWithContext:context children:[NSArray arrayWithArray:children]];
    }
    NSString * _Nonnull inputKey = input.allKeys.firstObject;
    if (inputKey.length == 0) {
        @throw [WPSPBadInputException new]; // Bad key ""
    }
    
    id inputValue = input[inputKey];
    WPSPASTCriterionNode *parsed = self.parserConfig.criterionParser(context, inputKey, inputValue);
    if (!parsed) {
        parsed = [[WPSPASTUnknownCriterionNode alloc] initWithContext:context key:inputKey value:inputValue];
        if (self.parserConfig.throwOnUnknownCriterion) {
            @throw [WPSPUnknownCriterionException new];
        }
    }
    
    return parsed;
}

- (WPSPASTValueNode *)parseValueWithContext:(WPSPParsingContext *)context input:(id)input {
    if (!input || [NSNull.null isEqual:input]) {
        return [[WPSPNullValueNode alloc] initWithContext:context value:NSNull.null];
    }
    if ([WPJsonUtil isBoolNumber:input]) {
        return [[WPSPBooleanValueNode alloc] initWithContext:context value:input];
    }
    if ([input isKindOfClass:NSNumber.class]) {
        return [[WPSPNumberValueNode alloc] initWithContext:context value:input];
    }
    if ([input isKindOfClass:NSString.class]) {
        return [[WPSPStringValueNode alloc] initWithContext:context value:input];
    }
    if ([input isKindOfClass:NSArray.class]) {
        @throw [WPSPBadInputException new]; // array values are not accepted
    }
    if (![input isKindOfClass:NSDictionary.class]) {
        @throw [WPSPBadInputException new]; // NSStringFromClass(input.class) is not accepted
    }
    
    NSDictionary *inputDictionary = input;
    if (inputDictionary.count != 1) {
        @throw [WPSPBadInputException new]; // object values can only have 1 key defining their type
    }
    NSString *inputKey = inputDictionary.allKeys.firstObject;
    if (inputKey.length == 0) {
        @throw [WPSPBadInputException new]; // bad key ""
    }
    id inputValue = inputDictionary[inputKey];
    WPSPASTValueNode *parsed = self.parserConfig.valueParser(context, inputKey, inputValue);
    if (!parsed) {
        parsed = [[WPSPASTUnknownValueNode alloc] initWithContext:context key:inputKey value:inputValue];
        if (self.parserConfig.throwOnUnknownValue) {
            @throw [WPSPUnknownValueException new];
        }
    }
    return parsed;
}

@end
