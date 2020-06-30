//
//  WPSPGeoCircle.h
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPGeoLocation.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPGeoCircle : NSObject
@property (nonnull, readonly) WPSPGeoLocation *center;
@property (readonly, assign) double radiusMeters;

- (instancetype) initWithCenter:(WPSPGeoLocation *)center radiusMeters:(double)radiusMeters;
@end

NS_ASSUME_NONNULL_END
