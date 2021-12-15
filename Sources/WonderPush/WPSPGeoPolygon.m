//
//  WPSPGeoPolygon.m
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPGeoPolygon.h"

@implementation WPSPGeoPolygon

- (instancetype)initWithPoints:(NSArray<WPSPGeoLocation *> *)points {
    if (self = [super init]) {
        _points = [NSArray arrayWithArray:points];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) return NO;
    WPSPGeoPolygon *other = object;
    return [other.points isEqual:self.points];
}

@end
