//
//  WPSPConfigurableCriterionNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPConfigurableCriterionNodeParser.h"

@interface WPSPConfigurableCriterionNodeParser ()
@property (nonnull, readonly) NSMutableDictionary<NSString *, WPSPASTCriterionNodeParser> *exactNameParsers;
@property (nonnull, readonly) NSMutableArray<WPSPASTCriterionNodeParser> *dynamicNameParsers;
@end

@implementation WPSPConfigurableCriterionNodeParser

- (instancetype) init {
    if (self = [super init]) {
        _exactNameParsers = [NSMutableDictionary new];
        _dynamicNameParsers = [NSMutableArray new];
    }
    return self;
}

- (void)registerExactNameParserWithKey:(NSString *)key parser:(WPSPASTCriterionNodeParser)parser {
    WPSPASTCriterionNodeParser oldParser = self.exactNameParsers[key];
    if (oldParser) {
        @throw @"CriterionParserAlreadyExistsForKey";
    }
    self.exactNameParsers[key] = parser;
}

- (void)registerDynamicNameParser:(WPSPASTCriterionNodeParser)parser {
    [self.dynamicNameParsers addObject:parser];
}

- (WPSPASTCriterionNode *)parseCriterionWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input {

    WPSPASTCriterionNodeParser exactNameParser = self.exactNameParsers[key];

    if (exactNameParser) {
        return [exactNameParser parseCriterionWithContext:context key:key input:input];
    }
    
    for (WPSPASTCriterionNodeParser parser in self.dynamicNameParsers) {
        WPSPASTCriterionNode *parsed = [parser parseCriterionWithContext:context key:key input:input];
        if (parsed) return parsed;
    }
    return nil;
}
@end
