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
@class WPSPDateValueNode;
@class WPSPRelativeDateValueNode;
@class WPSPDurationValueNode;
@class WPSPGeoLocationValueNode;
@class WPSPGeoBoxValueNode;
@class WPSPGeoCircleValueNode;
@class WPSPGeoPolygonValueNode;

@protocol WPSPASTValueVisitor <NSObject>

-(id) visitASTUnknownValueNode:(WPSPASTUnknownValueNode *)node;
-(id) visitNullValueNode:(WPSPNullValueNode *)node;
-(id) visitBooleanValueNode:(WPSPBooleanValueNode *)node;
-(id) visitNumberValueNode:(WPSPNumberValueNode *)node;
-(id) visitStringValueNode:(WPSPStringValueNode *)node;
-(id) visitDateValueNode:(WPSPDateValueNode *)node;
-(id) visitRelativeDateValueNode:(WPSPRelativeDateValueNode *)node;
-(id) visitDurationValueNode:(WPSPDurationValueNode *)node;
-(id) visitGeoLocationValueNode:(WPSPGeoLocationValueNode *)node;
-(id) visitGeoBoxValueNode:(WPSPGeoBoxValueNode *)node;
-(id) visitGeoCircleValueNode:(WPSPGeoCircleValueNode *)node;
-(id) visitGeoPolygonValueNode:(WPSPGeoPolygonValueNode *)node;

@end

NS_ASSUME_NONNULL_END
