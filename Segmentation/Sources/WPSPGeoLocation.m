//
//  WPSPGeoLocation.m
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPGeoLocation.h"

@implementation WPSPGeoLocation

- (instancetype)initWithLat:(double)lat lon:(double)lon {
    if (self = [super init]) {
        _lat = lat;
        _lon = lon;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) return NO;
    WPSPGeoLocation *other = object;
    return other.lat == self.lat && other.lon == self.lon;
}
@end
