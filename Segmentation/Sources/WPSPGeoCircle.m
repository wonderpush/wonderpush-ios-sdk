//
//  WPSPGeoCircle.m
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPGeoCircle.h"

@implementation WPSPGeoCircle
- (instancetype) initWithCenter:(WPSPGeoLocation *)center radiusMeters:(double)radiusMeters {
    if (self = [super init]) {
        _center = center;
        _radiusMeters = radiusMeters;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) return NO;
    WPSPGeoCircle *other = object;
    return [other.center isEqual:self.center] && self.radiusMeters == other.radiusMeters;
}
@end
