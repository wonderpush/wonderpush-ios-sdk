//
//  WPSPConfigurableCriterionNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPConfigurableCriterionNodeParser.h"

@interface WPSPConfigurableCriterionNodeParser ()
@property (nonnull, readonly) NSMutableDictionary<NSString *, id<WPSPASTCriterionNodeParser>> *exactNameParsers;
@property (nonnull, readonly) NSMutableArray<id<WPSPASTCriterionNodeParser>> *dynamicNameParsers;
@end

@implementation WPSPConfigurableCriterionNodeParser

- (instancetype) init {
    if (self = [super init]) {
        _exactNameParsers = [NSMutableDictionary new];
        _dynamicNameParsers = [NSMutableArray new];
    }
    return self;
}

- (void)registerExactNameParserWithKey:(NSString *)key parser:(id<WPSPASTCriterionNodeParser>)parser {
    id<WPSPASTCriterionNodeParser> oldParser = self.exactNameParsers[key];
    if (oldParser) {
        @throw @"CriterionParserAlreadyExistsForKey";
    }
    self.exactNameParsers[key] = parser;
}

- (void)registerDynamicNameParser:(id<WPSPASTCriterionNodeParser>)parser {
    [self.dynamicNameParsers addObject:parser];
}

- (WPSPASTCriterionNode *)parseCriterionWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input {

    id<WPSPASTCriterionNodeParser> exactNameParser = self.exactNameParsers[key];

    if (exactNameParser) {
        return [exactNameParser parseCriterionWithContext:context key:key input:input];
    }
    
    for (id<WPSPASTCriterionNodeParser> parser in self.dynamicNameParsers) {
        WPSPASTCriterionNode *parsed = [parser parseCriterionWithContext:context key:key input:input];
        if (parsed) return parsed;
    }
    return nil;
}
@end
