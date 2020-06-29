//
//  WPSPASTValueVisitor.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class WPSPASTUnknownValueNode;
@class WPSPNullValueNode;
@class WPSPBooleanValueNode;
@class WPSPNumberValueNode;
@class WPSPStringValueNode;

@protocol WPSPASTValueVisitor <NSObject>

-(id) visitASTUnknownValueNode:(WPSPASTUnknownValueNode *)node;
-(id) visitNullValueNode:(WPSPNullValueNode *)node;
-(id) visitBooleanValueNode:(WPSPBooleanValueNode *)node;
-(id) visitNumberValueNode:(WPSPNumberValueNode *)node;
-(id) visitStringValueNode:(WPSPStringValueNode *)node;

@end

NS_ASSUME_NONNULL_END
