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

- (WPSPASTValueNode * _Nullable)parseValueWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input {
    WPSPASTValueNodeParser exactNameParser = self.exactNameParsers[key];

    if (exactNameParser) {
        return exactNameParser(context, key, input);
    }
    
    for (WPSPASTValueNodeParser parser in self.dynamicNameParsers) {
        WPSPASTValueNode *parsed = parser(context, key, input);
        if (parsed) return parsed;
    }

    return nil;
}

@end
