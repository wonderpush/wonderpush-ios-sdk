//
//  WPSPGeohash.m
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPGeohash.h"
#import "WPSPExceptions.h"

@implementation WPSPGeohash


+ (NSDictionary<NSNumber *, NSNumber *> *) base32CodesDict {
    static NSDictionary *rtn = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *base32EncodeTable = @"0123456789bcdefghjkmnpqrstuvwxyz";
        NSMutableDictionary *dict = [NSMutableDictionary new];
        for (NSInteger i = 0; i < base32EncodeTable.length; i++) {
            [dict setObject:[NSNumber numberWithInteger:i] forKey:[NSNumber numberWithUnsignedShort:[base32EncodeTable characterAtIndex:i]]];
        }
        rtn = [NSDictionary dictionaryWithDictionary:dict];
    });
    return rtn;
}

+ (instancetype _Nullable) parse:(NSString *)geohash {
    if (!geohash) return nil;
    geohash = [geohash lowercaseString];
    BOOL isLon = YES;
    double maxLat = +90;
    double minLat = -90;
    double maxLon = +180;
    double minLon = -180;
    double mid;
    NSDictionary<NSNumber *, NSNumber *> *base32CodesDict = self.base32CodesDict;
    // See: https://github.com/sunng87/node-geohash/blob/87ca0f9d6213a13b3335a6889659cad59e83d286/main.js#L170-L204
    for (NSUInteger i = 0, l = geohash.length; i < l; i++) {
        unichar c = [geohash characterAtIndex:i];
        NSNumber *hashValueNumber = base32CodesDict[[NSNumber numberWithUnsignedShort:c]];
        if (!hashValueNumber) @throw [WPSPBadInputException new]; // "character \"" + c + "\" is not valid in a geohash"
        NSInteger hashValue = hashValueNumber.integerValue;
        for (int bits = 4; bits >= 0; bits--) {
            int bit = (hashValue >> bits) & 1;
            if (isLon) {
                mid = (maxLon + minLon) / 2;
                if (bit == 1) {
                    minLon = mid;
                } else {
                    maxLon = mid;
                }
            } else {
                mid = (maxLat + minLat) / 2;
                if (bit == 1) {
                    minLat = mid;
                } else {
                    maxLat = mid;
                }
            }
            isLon = !isLon;
        }
    }
    return [[WPSPGeohash alloc] initWithGeohash:geohash top:maxLat right:maxLon bottom:minLat left:minLon];

    // TODO: write unit tests here.
}

- (instancetype) initWithGeohash:(NSString *)geohash top:(double)top right:(double)right bottom:(double)bottom left:(double)left {
    if (self = [super initWithTop:top right:right bottom:bottom left:left]) {
        _geohash = geohash;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) return NO;
    WPSPGeohash *other = object;
    return [self.geohash isEqualToString:other.geohash] && self.top == other.top && self.right == other.right && self.bottom == other.bottom && self.left == other.left;
}
@end
