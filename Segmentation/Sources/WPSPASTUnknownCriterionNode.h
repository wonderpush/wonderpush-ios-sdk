//
//  WPSPASTUnknownCriterionNode.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPASTCriterionNode.h"
#import "WPSPParsingContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPASTUnknownCriterionNode : WPSPASTCriterionNode
@property (nonnull, readonly) NSString *key;
@property (nonnull, readonly) id value;

- (instancetype) initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value;

@end

NS_ASSUME_NONNULL_END
