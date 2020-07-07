//
//  WPASTCriterionNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPASTCriterionNode.h"

@implementation WPSPASTCriterionNode
- (instancetype) initWithContext:(WPSPParsingContext *)context {
    if (self = [super init]) {
        _context = context;
    }
    return self;
}

- (id) accept:(id<WPSPASTCriterionVisitor>)visitor {
    @throw @"abstract";
}
@end

@implementation WPSPASTUnknownCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value {
    if (self = [super initWithContext:context]) {
        _key = key;
        _value = value;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitASTUnknownCriterionNode:self];
}

@end

@implementation WPSPMatchAllCriterionNode

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitMatchAllCriterionNode:self];
}

@end

@implementation WPSPAndCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context children:(NSArray<WPSPASTCriterionNode *> *)children {
    if (self = [super initWithContext:context]) {
        _children = [NSArray arrayWithArray:children];
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitAndCriterionNode:self];
}

@end

@implementation WPSPOrCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context children:(NSArray<WPSPASTCriterionNode *> *)children {
    if (self = [super initWithContext:context]) {
        _children = [NSArray arrayWithArray:children];
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitOrCriterionNode:self];
}

@end

@implementation WPSPNotCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context child:(WPSPASTCriterionNode *)child {
    if (self = [super initWithContext:context]) {
        _child = child;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitNotCriterionNode:self];
}

@end

@implementation WPSPLastActivityDateCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context dateComparison:(WPSPASTCriterionNode *)dateComparison {
    if (self = [super initWithContext:context]) {
        _dateComparison = dateComparison;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitLastActivityDateCriterionNode:self];
}

@end

@implementation WPSPPresenceCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context present:(BOOL)present sinceDateComparison:(WPSPASTCriterionNode *)sinceDateComparison elapsedTimeComparison:(WPSPASTCriterionNode *)elapsedTimeComparison {
    if (self = [super initWithContext:context]) {
        _present = present;
        _sinceDateComparison = sinceDateComparison;
        _elapsedTimeComparison = elapsedTimeComparison;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitPresenceCriterionNode:self];
}

@end

@implementation WPSPGeoCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context locationComparison:(WPSPASTCriterionNode *)locationComparison dateComparison:(WPSPASTCriterionNode *)dateComparison {
    if (self = [super initWithContext:context]) {
        _locationComparison = locationComparison;
        _dateComparison = dateComparison;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitGeoCriterionNode:self];
}

@end

@implementation WPSPSubscriptionStatusCriterionNode

+ (WPSPSubscriptionStatus)subscriptionStatusWithString:(NSString *)input {
    if ([input isEqualToString:@"optIn"]) {
        return WPSPSubscriptionStatusOptIn;
    }
    if ([input isEqualToString:@"optOut"]) {
        return WPSPSubscriptionStatusOptOut;
    }
    if ([input isEqualToString:@"softOptOut"]) {
        return WPSPSubscriptionStatusSoftOptOut;
    }
    return -1;
}

+ (WPSPSubscriptionStatusCriterionNode *)subscriptionStatusCriterionNodeWithContext:(WPSPParsingContext *)context input:(NSString *)input {
    WPSPSubscriptionStatus subscriptionStatus = [self subscriptionStatusWithString:input];
    if (subscriptionStatus == -1) return nil;
    return [[self alloc] initWithContext:context subscriptionStatus:subscriptionStatus];
}

- (instancetype)initWithContext:(WPSPParsingContext *)context subscriptionStatus:(WPSPSubscriptionStatus)subscriptionStatus {
    if (self = [super initWithContext:context]) {
        _subscriptionStatus = subscriptionStatus;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitSubscriptionStatusCriterionNode:self];
}

@end

@implementation WPSPJoinCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context child:(WPSPASTCriterionNode *)child {
    if (self = [super initWithContext:context]) {
        _child = child;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitJoinCriterionNode:self];
}

@end

@implementation WPSPEqualityCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context value:(WPSPASTValueNode *)value {
    if (self = [super initWithContext:context]) {
        _value = value;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitEqualityCriterionNode:self];
}

@end

@implementation WPSPAnyCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context values:(NSArray<WPSPASTValueNode *> *)values {
    if (self = [super initWithContext:context]) {
        _values = [NSArray arrayWithArray:values];
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitAnyCriterionNode:self];
}

@end

@implementation WPSPAllCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context values:(NSArray<WPSPASTValueNode *> *)values {
    if (self = [super initWithContext:context]) {
        _values = [NSArray arrayWithArray:values];
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitAllCriterionNode:self];
}

@end

@implementation WPSPComparisonCriterionNode

+ (WPSPComparator)comparatorWithString:(NSString *)input {
    if ([input isEqualToString:@"gt"]) return WPSPComparatorGt;
    if ([input isEqualToString:@"gte"]) return WPSPComparatorGte;
    if ([input isEqualToString:@"lt"]) return WPSPComparatorLt;
    if ([input isEqualToString:@"lte"]) return WPSPComparatorLte;
    return -1;
}

- (instancetype)initWithContext:(WPSPParsingContext *)context comparator:(WPSPComparator)comparator value:(WPSPASTValueNode *)value {
    if (self = [super initWithContext:context]) {
        _comparator = comparator;
        _value = value;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitComparisonCriterionNode:self];
}

@end

@implementation WPSPPrefixCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context value:(WPSPStringValueNode *)value {
    if (self = [super initWithContext:context]) {
        _value = value;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitPrefixCriterionNode:self];
}

@end

@implementation WPSPInsideCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context value:(WPSPGeoAbstractAreaValueNode *)value {
    if (self = [super initWithContext:context]) {
        _value = value;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitInsideCriterionNode:self];
}

@end
