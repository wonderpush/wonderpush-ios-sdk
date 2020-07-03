//
//  WPSPDefaultCriterionNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPDefaultCriterionNodeParser.h"
#import "WPSPDataSource.h"
#import "WPSPSegmentationDSLParser.h"
#import "WPSPExceptions.h"
#import "WPJsonUtil.h"

@implementation WPSPDefaultCriterionNodeParser

- (instancetype)init {
    if (self = [super init]) {
        // Dynamic: Field access
        [self registerDynamicNameParser:[[self class] parseDynamicDotField]];
        // Generic combiners
        [self registerExactNameParserWithKey:@"and" parser:[self.class parseAnd]];
        [self registerExactNameParserWithKey:@"or" parser:[self.class parseOr]];
        [self registerExactNameParserWithKey:@"not" parser:[self.class parseNot]];
        // Available only on installation data sources
        [self registerExactNameParserWithKey:@"lastActivityDate" parser:[self.class parseLastActivityDate]];
        [self registerExactNameParserWithKey:@"presence" parser:[self.class parsePresence]];
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

+ (WPSPASTCriterionNodeParser) parseAnd {
    return CRITERION_NODE_PARSER_BLOCK {
        NSArray <NSDictionary *> *checkedInputValue = [self ensureArrayOfObjects:input forKey:key];
        NSMutableArray <WPSPASTCriterionNode *> *parsed = [[NSMutableArray alloc] initWithCapacity:checkedInputValue.count];
        for (NSDictionary *inputItem in checkedInputValue) {
            [parsed addObject:[context.parser parseCriterionWithContext:context input:inputItem]];
        }
        return [[WPSPAndCriterionNode alloc] initWithContext:context children:parsed];
    };
}

+ (WPSPASTCriterionNodeParser) parseOr {
    return CRITERION_NODE_PARSER_BLOCK {
        NSArray <NSDictionary *> *checkedInputValue = [self ensureArrayOfObjects:input forKey:key];
        NSMutableArray <WPSPASTCriterionNode *> *parsed = [[NSMutableArray alloc] initWithCapacity:checkedInputValue.count];
        for (NSDictionary *inputItem in checkedInputValue) {
            [parsed addObject:[context.parser parseCriterionWithContext:context input:inputItem]];
        }
        return [[WPSPOrCriterionNode alloc] initWithContext:context children:parsed];
    };
}

+ (WPSPASTCriterionNodeParser) parseNot {
    return CRITERION_NODE_PARSER_BLOCK {
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPASTCriterionNode *parsed = [context.parser parseCriterionWithContext:context input:checkedInputValue];
        return [[WPSPNotCriterionNode alloc] initWithContext:context child:parsed];
    };
}

+ (WPSPASTCriterionNodeParser) parseLastActivityDate {
    return CRITERION_NODE_PARSER_BLOCK {
        if (![context.dataSource isKindOfClass:WPSPInstallationSource.class]) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of \"installation\"", key]];
        }
        
        WPSPInstallationSource *contextDataSource = (WPSPInstallationSource *)context.dataSource;
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPDataSource *dataSource = [[WPSPLastActivityDateSource alloc] initWithParent:contextDataSource];
        WPSPASTCriterionNode *dateCriterion = [context.parser parseCriterionWithContext:[context withDataSource:dataSource] input:checkedInputValue];
        return [[WPSPLastActivityDateCriterionNode alloc] initWithContext:context dateComparison:dateCriterion];
    };
}

+ (WPSPASTCriterionNodeParser) parsePresence {
    return CRITERION_NODE_PARSER_BLOCK {
        if (![context.dataSource isKindOfClass:WPSPInstallationSource.class]) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of \"installation\"", key]];
        }
        
        WPSPInstallationSource *contextDataSource = (WPSPInstallationSource *)context.dataSource;
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        BOOL present = [self ensureBoolean:checkedInputValue[@"present"] forKey:[key stringByAppendingString:@".present"]];
        WPSPPresenceSinceDateSource *sinceDateSource = [[WPSPPresenceSinceDateSource alloc] initWithParent:contextDataSource present:present];
        WPSPASTCriterionNode *sinceDateCriterion = nil;
        if (checkedInputValue[@"sinceDate"]) {
            sinceDateCriterion = [context.parser parseCriterionWithContext:[context withDataSource:sinceDateSource] input:[self ensureDictionary:checkedInputValue[@"sinceDate"] forKey:[key stringByAppendingString:@".sinceDate"]]];
        }
        WPSPPresenceElapsedTimeSource *elapsedTimeSource = [[WPSPPresenceElapsedTimeSource alloc] initWithParent:contextDataSource present:present];
        WPSPASTCriterionNode *elapsedTimeCriterion = nil;
        if (checkedInputValue[@"elapsedTime"]) {
            elapsedTimeCriterion = [context.parser parseCriterionWithContext:[context withDataSource:elapsedTimeSource] input:[self ensureDictionary:checkedInputValue[@"elapsedTime"] forKey:[key stringByAppendingString:@".elapsedTime"]]];
        }
        
        return [[WPSPPresenceCriterionNode alloc] initWithContext:context present:present sinceDateComparison:sinceDateCriterion elapsedTimeComparison:elapsedTimeCriterion];
    };
}

// TODO: finish me

+ (NSArray *) ensureArray:(id)input forKey:(NSString *)key {
    if (![input isKindOfClass:NSArray.class]) {
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects an array", key]];
    }
    return input;
}

+ (NSArray <NSDictionary *> *) ensureArrayOfObjects:(id)input forKey:(NSString *)key {
    NSArray *inputArray = [self ensureArray:input forKey:key];
    for (id elt in inputArray) {
        if (![elt isKindOfClass:NSDictionary.class]) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects an array of objects", key]];
        }
    }
    return input;
}

+ (NSDictionary *) ensureDictionary:(id)input forKey:(NSString *)key {
    if (![input isKindOfClass:NSDictionary.class]) {
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects an object", key]];
    }
    return input;
}

+ (NSString *) ensureString:(id)input forKey:(NSString *)key {
    if (![input isKindOfClass:NSString.class]) {
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects a string", key]];
    }
    return input;
}

+ (BOOL) ensureBoolean:(id)input forKey:(NSString *)key {
    if (![input isKindOfClass:NSNumber.class] || ![WPJsonUtil isBoolNumber:input]) {
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects a boolean", key]];
    }
    return [input boolValue];
}

@end
