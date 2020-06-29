//
//  WPSPConfigurableValueNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPConfigurableValueNodeParser.h"

@interface WPSPConfigurableValueNodeParser ()

@property (nonnull, readonly) NSMutableDictionary<NSString *, WPSPASTValueNodeParser> *exactNameParsers;
@property (nonnull, readonly) NSMutableArray<WPSPASTValueNodeParser> *dynamicNameParsers;

@end

@implementation WPSPConfigurableValueNodeParser

- (instancetype) init {
    if (self = [super init]) {
        _exactNameParsers = [NSMutableDictionary new];
        _dynamicNameParsers = [NSMutableArray new];
    }
    return self;
}

- (void)registerExactNameParserWithKey:(NSString *)key parser:(WPSPASTValueNodeParser)parser {
    WPSPASTValueNodeParser oldParser = self.exactNameParsers[key];
    if (oldParser) {
        @throw @"ValueParserAlreadyExistsForKey";
    }
    self.exactNameParsers[key] = parser;
}

- (void)registerDynamicNameParser:(WPSPASTValueNodeParser)parser {
    [self.dynamicNameParsers addObject:parser];
}

- (WPSPASTValueNode *)parseValueWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input {

    WPSPASTValueNodeParser exactNameParser = self.exactNameParsers[key];

    if (exactNameParser) {
        return [exactNameParser parseValueWithContext:context key:key input:input];
    }
    
    for (WPSPASTValueNodeParser parser in self.dynamicNameParsers) {
        WPSPASTValueNode *parsed = [parser parseValueWithContext:context key:key input:input];
        if (parsed) return parsed;
    }
    return nil;
}
@end
