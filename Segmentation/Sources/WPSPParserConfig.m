//
//  WPSPParserConfig.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPParserConfig.h"

@implementation WPSPParserConfig

- (instancetype) initWithValueParser:(id<WPSPASTValueNodeParser>)valueParser criterionParser:(id<WPSPASTCriterionNodeParser>)criterionParser {
    return [self initWithValueParser:valueParser criterionParser:criterionParser throwOnUnknownCriterion:NO throwOnUnknownValue:NO];
}

- (instancetype) initWithValueParser:(id<WPSPASTValueNodeParser>)valueParser criterionParser:(id<WPSPASTCriterionNodeParser>)criterionParser throwOnUnknownCriterion:(BOOL)throwOnUnknownCriterion throwOnUnknownValue:(BOOL)throwOnUnknownValue {
    if (self = [super init]) {
        _valueParser = valueParser;
        _criterionParser = criterionParser;
        _throwOnUnknownValue = throwOnUnknownValue;
        _throwOnUnknownCriterion = throwOnUnknownCriterion;
    }
    return self;
}

@end
