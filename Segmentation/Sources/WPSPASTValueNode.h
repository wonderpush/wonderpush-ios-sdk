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
#import "WPSPISO8601Duration.h"
#import "WPSPGeoLocation.h"
#import "WPSPGeoBox.h"
#import "WPSPGeoCircle.h"
#import "WPSPGeoPolygon.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPASTValueNode<__covariant T> : NSObject
@property (nonnull, readonly) WPSPParsingContext *context;
@property (nonnull, readonly) T value;

- (instancetype) initWithContext:(WPSPParsingContext *)context value:(T)value;
- (id) accept:(id<WPSPASTValueVisitor>)visitor;

@end

@interface WPSPASTUnknownValueNode : WPSPASTValueNode<id>
@property (nonnull, readonly) NSString *key;

- (instancetype) initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value;

@end

@interface WPSPNullValueNode : WPSPASTValueNode<NSNull *>
@end

@interface WPSPBooleanValueNode : WPSPASTValueNode<NSNumber *>
@end

@interface WPSPNumberValueNode : WPSPASTValueNode<NSNumber *>
@end

@interface WPSPStringValueNode : WPSPASTValueNode<NSString *>
@end

@interface WPSPRelativeDateValueNode : WPSPASTValueNode<NSNumber *>
@property (nonnull, readonly) WPSPISO8601Duration *duration;

- (instancetype) initWithContext:(WPSPParsingContext *)context duration:(WPSPISO8601Duration *)duration;

@end

@interface WPSPDateValueNode : WPSPASTValueNode<NSNumber *>
@end

@interface WPSPDurationValueNode : WPSPASTValueNode<NSNumber *>

- (instancetype) initWithContext:(WPSPParsingContext *)context duration:(WPSPISO8601Duration *)duration;

@end

@interface WPSPGeoLocationValueNode : WPSPASTValueNode<WPSPGeoLocation *>
@end

@interface WPSPGeoAbstractAreaValueNode<__covariant T> : WPSPASTValueNode<T>
@end

@interface WPSPGeoBoxValueNode : WPSPGeoAbstractAreaValueNode<WPSPGeoBox *>
@end

@interface WPSPGeoCircleValueNode : WPSPGeoAbstractAreaValueNode<WPSPGeoCircle *>
@end

@interface WPSPGeoPolygonValueNode : WPSPGeoAbstractAreaValueNode<WPSPGeoPolygon *>
@end

NS_ASSUME_NONNULL_END
