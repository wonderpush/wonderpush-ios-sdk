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

@protocol WPSPASTCriterionVisitor <NSObject>

- (id) visitMatchAllCriterionNode:(WPSPMatchAllCriterionNode *)node;
- (id) visitAndCriterionNode:(WPSPAndCriterionNode *)node;
- (id) visitASTUnknownCriterionNode:(WPSPASTUnknownCriterionNode *)node;

@end
NS_ASSUME_NONNULL_END
