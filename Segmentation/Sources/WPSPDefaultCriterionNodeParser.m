//
//  WPSPDefaultCriterionNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPDefaultCriterionNodeParser.h"
#import "WPSPFieldSource.h"
#import "WPSPSegmentationDSLParser.h"
#import "WPSPExceptions.h"
@implementation WPSPDefaultCriterionNodeParser

- (instancetype)init {
    if (self = [super init]) {
        [self registerDynamicNameParser:[[self class] parseDynamicDotField]];

        // TODO: code the rest
    }
    return self;
}

+ (NSDictionary *) ensureNSDictionary:(id)input {
    if (![input isKindOfClass:NSDictionary.class]) {
        @throw [WPSPBadInputException new];
    }
    return input;
}

+ (WPSPASTCriterionNodeParser) parseDynamicDotField {
    return CRITERION_NODE_PARSER_BLOCK {
        if ([key characterAtIndex:0] == '.') {
            WPSPFieldSource *fieldSource = [[WPSPFieldSource alloc]
                                            initWithParent:context.dataSource
                                            fieldPath:[WPSPFieldPath pathByParsing:[key substringFromIndex:1]]];
            WPSPParsingContext *newContext = [context withDataSource:fieldSource];
            
            return [context.parser
                    parseCriterionWithContext:newContext
                    input:[[self class] ensureNSDictionary:input]];
        }
        return nil;
    };
}

@end
