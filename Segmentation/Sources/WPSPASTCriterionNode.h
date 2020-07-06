//
//  WPASTCriterionNode.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPParsingContext.h"
#import "WPSPASTCriterionVisitor.h"
#import "WPSPASTValueNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPASTCriterionNode : NSObject
@property (nonnull, readonly) WPSPParsingContext *context;

- (instancetype) initWithContext:(WPSPParsingContext *)context;

- (id) accept:(id<WPSPASTCriterionVisitor>)visitor;

@end

@interface WPSPASTUnknownCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSString *key;
@property (nonnull, readonly) id value;

- (instancetype) initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value;

@end

@interface WPSPMatchAllCriterionNode : WPSPASTCriterionNode

@end

@interface WPSPAndCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSArray<WPSPASTCriterionNode *> *children;

- (instancetype) initWithContext:(WPSPParsingContext *)context children:(NSArray<WPSPASTCriterionNode *> *)children;
@end

@interface WPSPOrCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSArray<WPSPASTCriterionNode *> *children;

- (instancetype) initWithContext:(WPSPParsingContext *)context children:(NSArray<WPSPASTCriterionNode *> *)children;
@end

@interface WPSPNotCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPASTCriterionNode *child;

- (instancetype) initWithContext:(WPSPParsingContext *)context child:(WPSPASTCriterionNode *)child;
@end

@interface WPSPLastActivityDateCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPASTCriterionNode *dateComparison;

- (instancetype) initWithContext:(WPSPParsingContext *)context dateComparison:(WPSPASTCriterionNode *)child;
@end

@interface WPSPPresenceCriterionNode : WPSPASTCriterionNode
@property (assign, readonly) BOOL present;
@property (nonnull, readonly) WPSPASTCriterionNode *sinceDateComparison;
@property (nonnull, readonly) WPSPASTCriterionNode *elapsedTimeComparison;

- (instancetype) initWithContext:(WPSPParsingContext *)context
                         present:(BOOL)present
             sinceDateComparison:(WPSPASTCriterionNode *)sinceDateComparison
           elapsedTimeComparison:(WPSPASTCriterionNode *)elapsedTimeComparison;
@end

@interface WPSPGeoCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPASTCriterionNode *locationComparison;
@property (nonnull, readonly) WPSPASTCriterionNode *dateComparison;

- (instancetype) initWithContext:(WPSPParsingContext *)context
              locationComparison:(WPSPASTCriterionNode *)locationComparison
                  dateComparison:(WPSPASTCriterionNode *)dateComparison;
@end

typedef NS_ENUM(NSInteger, WPSPSubscriptionStatus) {
    WPSPSubscriptionStatusOptIn,
    WPSPSubscriptionStatusOptOut,
    WPSPSubscriptionStatusSoftOptOut,
};

@interface WPSPSubscriptionStatusCriterionNode : WPSPASTCriterionNode
@property (assign, readonly) WPSPSubscriptionStatus subscriptionStatus;

+ (WPSPSubscriptionStatusCriterionNode * _Nullable)subscriptionStatusCriterionNodeWithContext:(WPSPParsingContext *)context input:(NSString *)input;

- (instancetype) initWithContext:(WPSPParsingContext *)context
              subscriptionStatus:(WPSPSubscriptionStatus)subscriptionStatus;
@end

@interface WPSPJoinCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPASTCriterionNode *child;

- (instancetype) initWithContext:(WPSPParsingContext *)context child:(WPSPASTCriterionNode *)child;
@end

@interface WPSPEqualityCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPASTValueNode *value;

- (instancetype) initWithContext:(WPSPParsingContext *)context value:(WPSPASTValueNode *)value;
@end

@interface WPSPAnyCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSArray<WPSPASTValueNode *> *values;

- (instancetype) initWithContext:(WPSPParsingContext *)context values:(NSArray<WPSPASTValueNode *> *)values;
@end

@interface WPSPAllCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSArray<WPSPASTValueNode *> *values;

- (instancetype) initWithContext:(WPSPParsingContext *)context values:(NSArray<WPSPASTValueNode *> *)values;
@end

typedef NS_ENUM(NSInteger, WPSPComparator) {
    WPSPComparatorGt,
    WPSPComparatorGte,
    WPSPComparatorLt,
    WPSPComparatorLte,
};

@interface WPSPComparisonCriterionNode : WPSPASTCriterionNode
@property (assign, readonly) WPSPComparator comparator;
@property (nonnull, readonly) WPSPASTValueNode *value;

- (instancetype) initWithContext:(WPSPParsingContext *)context
                      comparator:(WPSPComparator)comparator
                           value:(WPSPASTValueNode *)value;

@end

@interface WPSPPrefixCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPStringValueNode *value;

- (instancetype) initWithContext:(WPSPParsingContext *)context
                           value:(WPSPStringValueNode *)value;

@end

@interface WPSPInsideCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) WPSPGeoAbstractAreaValueNode *value;

- (instancetype) initWithContext:(WPSPParsingContext *)context
                           value:(WPSPGeoAbstractAreaValueNode *)value;

@end


NS_ASSUME_NONNULL_END
