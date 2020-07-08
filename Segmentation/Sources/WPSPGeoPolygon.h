//
//  WPSPGeoPolygon.h
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPGeoLocation.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPGeoPolygon : NSObject
@property (readonly, nonnull) NSArray<WPSPGeoLocation *> *points;

- (instancetype) initWithPoints:(NSArray<WPSPGeoLocation *> *)points;
@end

NS_ASSUME_NONNULL_END
