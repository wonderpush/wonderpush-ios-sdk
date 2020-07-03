//
//  WPSPASTCriterionVisitor.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WPSPMatchAllCriterionNode;
@class WPSPAndCriterionNode;
@class WPSPASTUnknownCriterionNode;
@class WPSPOrCriterionNode;
@class WPSPNotCriterionNode;
@class WPSPGeoCriterionNode;
@class WPSPSubscriptionStatusCriterionNode;
@class WPSPLastActivityDateCriterionNode;
@class WPSPPresenceCriterionNode;
@class WPSPJoinCriterionNode;
@class WPSPEqualityCriterionNode;
@class WPSPAnyCriterionNode;
@class WPSPAllCriterionNode;
@class WPSPComparisonCriterionNode;
@class WPSPPrefixCriterionNode;
@class WPSPInsideCriterionNode;

@protocol WPSPASTCriterionVisitor <NSObject>

- (id) visitMatchAllCriterionNode:(WPSPMatchAllCriterionNode *)node;
- (id) visitAndCriterionNode:(WPSPAndCriterionNode *)node;
- (id) visitASTUnknownCriterionNode:(WPSPASTUnknownCriterionNode *)node;
- (id) visitOrCriterionNode:(WPSPOrCriterionNode *)node;
- (id) visitNotCriterionNode:(WPSPNotCriterionNode *)node;
- (id) visitGeoCriterionNode:(WPSPGeoCriterionNode *)node;
- (id) visitSubscriptionStatusCriterionNode:(WPSPSubscriptionStatusCriterionNode *)node;
- (id) visitLastActivityDateCriterionNode:(WPSPLastActivityDateCriterionNode *)node;
- (id) visitPresenceCriterionNode:(WPSPPresenceCriterionNode *)node;
- (id) visitJoinCriterionNode:(WPSPJoinCriterionNode *)node;
- (id) visitEqualityCriterionNode:(WPSPEqualityCriterionNode *)node;
- (id) visitAnyCriterionNode:(WPSPAnyCriterionNode *)node;
- (id) visitAllCriterionNode:(WPSPAllCriterionNode *)node;
- (id) visitComparisonCriterionNode:(WPSPComparisonCriterionNode *)node;
- (id) visitPrefixCriterionNode:(WPSPPrefixCriterionNode *)node;
- (id) visitInsideCriterionNode:(WPSPInsideCriterionNode *)node;

@end
NS_ASSUME_NONNULL_END
