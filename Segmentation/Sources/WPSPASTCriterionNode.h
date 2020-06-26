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
NS_ASSUME_NONNULL_BEGIN

@interface WPSPASTCriterionNode : NSObject
@property (nonnull, readonly) WPSPParsingContext *context;

- (instancetype) initWithContext:(WPSPParsingContext *)context;

- (id) accept:(id<WPSPASTCriterionVisitor>)visitor;

@end

NS_ASSUME_NONNULL_END
