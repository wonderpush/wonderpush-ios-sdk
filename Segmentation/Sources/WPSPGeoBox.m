//
//  WPSPGeoBox.m
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPGeoBox.h"

@implementation WPSPGeoBox

- (instancetype)initWithTop:(double)top right:(double)right bottom:(double)bottom left:(double)left {
    if (self = [super init]) {
        _top = top;
        _right = right;
        _bottom = bottom;
        _left = left;
    }
    return self;
}

- (double)centerLat {
    return (self.top + self.bottom) / 2;
}

- (double)centerLon {
    return (self.left + self.right) / 2;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) return NO;
    WPSPGeoBox *other = object;
    return self.top == other.top && self.right == other.right && self.bottom == other.bottom && self.left == other.left;
}
@end
