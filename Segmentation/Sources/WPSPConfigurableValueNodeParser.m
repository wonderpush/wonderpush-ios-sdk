//
//  WPSPConfigurableValueNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPConfigurableValueNodeParser.h"

@interface WPSPConfigurableValueNodeParser ()

@property (nonnull, readonly) NSMutableDictionary<NSString *, id<WPSPASTValueNodeParser>> *exactNameParsers;
@property (nonnull, readonly) NSMutableArray<id<WPSPASTValueNodeParser>> *dynamicNameParsers;

@end

@implementation WPSPConfigurableValueNodeParser

- (instancetype) init {
    if (self = [super init]) {
        _exactNameParsers = [NSMutableDictionary new];
        _dynamicNameParsers = [NSMutableArray new];
    }
    return self;
}

- (void)registerExactNameParserWithKey:(NSString *)key parser:(id<WPSPASTValueNodeParser>)parser {
    id<WPSPASTValueNodeParser> oldParser = self.exactNameParsers[key];
    if (oldParser) {
        @throw @"ValueParserAlreadyExistsForKey";
    }
    self.exactNameParsers[key] = parser;
}

- (void)registerDynamicNameParser:(id<WPSPASTValueNodeParser>)parser {
    [self.dynamicNameParsers addObject:parser];
}

- (WPSPASTValueNode *)parseValueWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input {

    id<WPSPASTValueNodeParser> exactNameParser = self.exactNameParsers[key];

    if (exactNameParser) {
        return [exactNameParser parseValueWithContext:context key:key input:input];
    }
    
    for (id<WPSPASTValueNodeParser> parser in self.dynamicNameParsers) {
        WPSPASTValueNode *parsed = [parser parseValueWithContext:context key:key input:input];
        if (parsed) return parsed;
    }
    return nil;
}
@end
