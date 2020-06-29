//
//  WPSPAndCriterionNode.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPParsingContext.h"
#import "WPSPASTCriterionNode.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPAndCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSArray<WPSPASTCriterionNode *> *children;

- (instancetype) initWithContext:(WPSPParsingContext *)context children:(NSArray<WPSPASTCriterionNode *> *)children;
@end

NS_ASSUME_NONNULL_END
