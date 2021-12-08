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
#import <WonderPushCommon/WPJsonUtil.h>

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
        [self registerExactNameParserWithKey:@"geo" parser:[self.class parseGeo]];
        [self registerExactNameParserWithKey:@"subscriptionStatus" parser:[self.class parseSubscriptionStatus]];
        [self registerExactNameParserWithKey:@"user" parser:[self.class parseUser]];
        [self registerExactNameParserWithKey:@"installation" parser:[self.class parseInstallation]];
        [self registerExactNameParserWithKey:@"event" parser:[self.class parseEvent]];
        [self registerExactNameParserWithKey:@"eq" parser:[self.class parseEq]];
        [self registerExactNameParserWithKey:@"any" parser:[self.class parseAny]];
        [self registerExactNameParserWithKey:@"all" parser:[self.class parseAll]];
        [self registerExactNameParserWithKey:@"gt" parser:[self.class parseGt]];
        [self registerExactNameParserWithKey:@"gte" parser:[self.class parseGte]];
        [self registerExactNameParserWithKey:@"lt" parser:[self.class parseLt]];
        [self registerExactNameParserWithKey:@"lte" parser:[self.class parseLte]];
        [self registerExactNameParserWithKey:@"prefix" parser:[self.class parsePrefix]];
        [self registerExactNameParserWithKey:@"inside" parser:[self.class parseInside]];
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
        WPSPInstallationSource *contextDataSource = [self ensureInstallationSource:context.dataSource forKey:key];
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPDataSource *dataSource = [[WPSPLastActivityDateSource alloc] initWithParent:contextDataSource];
        WPSPASTCriterionNode *dateCriterion = [context.parser parseCriterionWithContext:[context withDataSource:dataSource] input:checkedInputValue];
        return [[WPSPLastActivityDateCriterionNode alloc] initWithContext:context dateComparison:dateCriterion];
    };
}

+ (WPSPASTCriterionNodeParser) parsePresence {
    return CRITERION_NODE_PARSER_BLOCK {
        WPSPInstallationSource *contextDataSource = [self ensureInstallationSource:context.dataSource forKey:key];
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

+ (WPSPASTCriterionNodeParser) parseGeo {
    return CRITERION_NODE_PARSER_BLOCK {
        WPSPInstallationSource *contextDataSource = [self ensureInstallationSource:context.dataSource forKey:key];
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPGeoLocationSource *geoLocationSource = [[WPSPGeoLocationSource alloc] initWithParent:contextDataSource];
        WPSPASTCriterionNode *geoLocationCriterion = checkedInputValue[@"location"]
            ? [context.parser
               parseCriterionWithContext:[context withDataSource:geoLocationSource]
               input:[self ensureDictionary:checkedInputValue[@"location"] forKey:[key stringByAppendingString:@".location"]]]
            : nil;
        WPSPGeoDateSource *dateSource = [[WPSPGeoDateSource alloc] initWithParent:contextDataSource];
        WPSPASTCriterionNode *dateCriterion = checkedInputValue[@"date"]
            ? [context.parser
               parseCriterionWithContext:[context withDataSource:dateSource]
               input:[self ensureDictionary:checkedInputValue[@"date"] forKey:[key stringByAppendingString:@".date"]]]
            : nil;
        
        return [[WPSPGeoCriterionNode alloc] initWithContext:context locationComparison:geoLocationCriterion dateComparison:dateCriterion];
    };
}

+ (WPSPASTCriterionNodeParser) parseSubscriptionStatus {
    return CRITERION_NODE_PARSER_BLOCK {
        [self ensureInstallationSource:context.dataSource forKey:key];
        NSString *checkedInputValue = [self ensureString:input forKey:key];
        WPSPSubscriptionStatusCriterionNode *subscriptionStatusCriterion = [WPSPSubscriptionStatusCriterionNode subscriptionStatusCriterionNodeWithContext:context input:checkedInputValue];
        if (subscriptionStatusCriterion) return subscriptionStatusCriterion;
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" must be one of \"optIn\", \"optOut\" or \"softOptOut\"", key]];
    };
}

+ (WPSPASTCriterionNodeParser) parseUser {
    return CRITERION_NODE_PARSER_BLOCK {
        WPSPDataSource *rootDataSource = context.dataSource.rootDataSource;
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPParsingContext *newContext = [context withDataSource:[[WPSPUserSource alloc] initWithParent:nil]];
        if ([rootDataSource isKindOfClass:WPSPUserSource.class]) {
            return [context.parser parseCriterionWithContext:newContext input:checkedInputValue];
        } else if ([rootDataSource isKindOfClass:WPSPInstallationSource.class]) {
            return [[WPSPJoinCriterionNode alloc] initWithContext:newContext child:[context.parser parseCriterionWithContext:newContext input:checkedInputValue]];
        } else if ([rootDataSource isKindOfClass:WPSPEventSource.class]) {
            WPSPParsingContext *oneHopContext = [context withDataSource:[[WPSPInstallationSource alloc] initWithParent:nil]];
            WPSPParsingContext *twoHopsContext = [oneHopContext withDataSource:[[WPSPUserSource alloc] initWithParent:nil]];
            return [[WPSPJoinCriterionNode alloc]
                    initWithContext:oneHopContext
                    child:[[WPSPJoinCriterionNode alloc]
                           initWithContext:twoHopsContext
                           child:[context.parser parseCriterionWithContext:twoHopsContext input:checkedInputValue]]];
        }
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is not supported in this context", key]];
    };
}

+ (WPSPASTCriterionNodeParser) parseInstallation {
    return CRITERION_NODE_PARSER_BLOCK {
        WPSPDataSource *rootDataSource = context.dataSource.rootDataSource;
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPParsingContext *newContext = [context withDataSource:[[WPSPInstallationSource alloc] initWithParent:nil]];
        if ([rootDataSource isKindOfClass:WPSPUserSource.class]
            || [rootDataSource isKindOfClass:WPSPEventSource.class]) {
            return [[WPSPJoinCriterionNode alloc] initWithContext:newContext child:[context.parser parseCriterionWithContext:newContext input:checkedInputValue]];
        } else if ([rootDataSource isKindOfClass:WPSPInstallationSource.class]) {
            return [context.parser parseCriterionWithContext:newContext input:checkedInputValue];
        }
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is not supported in this context", key]];
    };
}

+ (WPSPASTCriterionNodeParser) parseEvent {
    return CRITERION_NODE_PARSER_BLOCK {
        WPSPDataSource *rootDataSource = context.dataSource.rootDataSource;
        NSDictionary *checkedInputValue = [self ensureDictionary:input forKey:key];
        WPSPParsingContext *newContext = [context withDataSource:[[WPSPEventSource alloc] initWithParent:nil]];
        if ([rootDataSource isKindOfClass:WPSPUserSource.class]) {
            WPSPParsingContext *oneHopContext = [context withDataSource:[[WPSPInstallationSource alloc] initWithParent:nil]];
            WPSPParsingContext *twoHopsContext = [oneHopContext withDataSource:[[WPSPEventSource alloc] initWithParent:nil]];
            return [[WPSPJoinCriterionNode alloc]
                    initWithContext:oneHopContext
                    child:[[WPSPJoinCriterionNode alloc]
                           initWithContext:twoHopsContext
                           child:[context.parser parseCriterionWithContext:twoHopsContext input:checkedInputValue]]];
        } else if ([rootDataSource isKindOfClass:WPSPInstallationSource.class]) {
            return [[WPSPJoinCriterionNode alloc] initWithContext:newContext child:[context.parser parseCriterionWithContext:newContext input:checkedInputValue]];
        } else if ([rootDataSource isKindOfClass:WPSPEventSource.class]) {
            return [context.parser parseCriterionWithContext:newContext input:checkedInputValue];
        }
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is not supported in this context", key]];
    };
}

+ (WPSPASTCriterionNodeParser) parseEq {
    return CRITERION_NODE_PARSER_BLOCK {
        if (context.dataSource.rootDataSource == context.dataSource) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of a field", key]];
        }
        return [[WPSPEqualityCriterionNode alloc] initWithContext:context value:[context.parser parseValueWithContext:context input:input]];
    };
}

+ (WPSPASTCriterionNodeParser) parseAny {
    return CRITERION_NODE_PARSER_BLOCK {
        if (context.dataSource.rootDataSource == context.dataSource) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of a field", key]];
        }
        NSArray *checkedInputValue = [self ensureArray:input forKey:key];
        NSInteger count = checkedInputValue.count;
        NSMutableArray <WPSPASTValueNode *> *values = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSInteger i = 0; i < count; i++) {
            [values addObject:[context.parser parseValueWithContext:context input:checkedInputValue[i]]];
        }
        return [[WPSPAnyCriterionNode alloc] initWithContext:context values:values];
    };
}

+ (WPSPASTCriterionNodeParser) parseAll {
    return CRITERION_NODE_PARSER_BLOCK {
        if (context.dataSource.rootDataSource == context.dataSource) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of a field", key]];
        }
        NSArray *checkedInputValue = [self ensureArray:input forKey:key];
        NSInteger count = checkedInputValue.count;
        NSMutableArray <WPSPASTValueNode *> *values = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSInteger i = 0; i < count; i++) {
            [values addObject:[context.parser parseValueWithContext:context input:checkedInputValue[i]]];
        }
        return [[WPSPAllCriterionNode alloc] initWithContext:context values:values];
    };
}

+ (WPSPASTCriterionNode * _Nullable) parseGtGteLtLteWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input comparator:(WPSPComparator)comparator {
    if (context.dataSource.rootDataSource == context.dataSource) {
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of a field", key]];
    }
    return [[WPSPComparisonCriterionNode alloc] initWithContext:context comparator:comparator value:[context.parser parseValueWithContext:context input:input]];
}

+ (WPSPASTCriterionNodeParser) parseGt {
    return CRITERION_NODE_PARSER_BLOCK {
        return [self parseGtGteLtLteWithContext:context key:key input:input comparator:WPSPComparatorGt];
    };
}

+ (WPSPASTCriterionNodeParser) parseGte {
    return CRITERION_NODE_PARSER_BLOCK {
        return [self parseGtGteLtLteWithContext:context key:key input:input comparator:WPSPComparatorGte];
    };
}

+ (WPSPASTCriterionNodeParser) parseLt {
    return CRITERION_NODE_PARSER_BLOCK {
        return [self parseGtGteLtLteWithContext:context key:key input:input comparator:WPSPComparatorLt];
    };
}

+ (WPSPASTCriterionNodeParser) parseLte {
    return CRITERION_NODE_PARSER_BLOCK {
        return [self parseGtGteLtLteWithContext:context key:key input:input comparator:WPSPComparatorLte];
    };
}

+ (WPSPASTCriterionNodeParser) parsePrefix {
    return CRITERION_NODE_PARSER_BLOCK {
        if (context.dataSource.rootDataSource == context.dataSource) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of a field", key]];
        }
        WPSPASTValueNode *value = [context.parser parseValueWithContext:context input:input];
        if (![value isKindOfClass:WPSPStringValueNode.class]) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects a string value", key]];
        }
        return [[WPSPPrefixCriterionNode alloc] initWithContext:context value:(WPSPStringValueNode *)value];
    };
}

+ (WPSPASTCriterionNodeParser) parseInside {
    return CRITERION_NODE_PARSER_BLOCK {
        if (context.dataSource.rootDataSource == context.dataSource) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of a field", key]];
        }
        WPSPASTValueNode *value = [context.parser parseValueWithContext:context input:input];
        if (![value isKindOfClass:WPSPGeoAbstractAreaValueNode.class]) {
            @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" expects a compatible geo value", key]];
        }
        return [[WPSPInsideCriterionNode alloc] initWithContext:context value:(WPSPGeoAbstractAreaValueNode *)value];
    };
}

+ (WPSPInstallationSource *) ensureInstallationSource:(WPSPDataSource *)dataSource forKey:(NSString *)key {
    if (![dataSource isKindOfClass:WPSPInstallationSource.class]) {
        @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" is only supported in the context of \"installation\"", key]];
    }
    return (WPSPInstallationSource *)dataSource;
}

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
