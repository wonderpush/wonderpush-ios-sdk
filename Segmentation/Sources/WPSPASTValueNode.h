//
//  WPSPASTValueNode.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPParsingContext.h"
#import "WPSPASTValueVisitor.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPASTValueNode<__covariant T> : NSObject
@property (nonnull, readonly) WPSPParsingContext *context;
@property (nonnull, readonly) T value;

- (instancetype) initWithContext:(WPSPParsingContext *)context value:(T)value;

- (id) accept:(id<WPSPASTValueVisitor>)visitor;


@end

NS_ASSUME_NONNULL_END
