//
//  WPSPGeoBox.h
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSPGeoBox : NSObject
@property (assign, readonly) double top;
@property (assign, readonly) double right;
@property (assign, readonly) double bottom;
@property (assign, readonly) double left;

- (instancetype) initWithTop:(double)top right:(double)right bottom:(double)bottom left:(double)left;
- (double) centerLat;
- (double) centerLon;
@end

NS_ASSUME_NONNULL_END
