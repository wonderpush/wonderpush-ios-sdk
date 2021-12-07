//
//  WPSPGeohash.h
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPGeoBox.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPGeohash : WPSPGeoBox
@property (nonnull, readonly) NSString *geohash;

+ (instancetype _Nullable) parse:(NSString *)geohash;

- (instancetype) initWithGeohash:(NSString *)geohash top:(double)top right:(double)right bottom:(double)bottom left:(double)left;

@end

NS_ASSUME_NONNULL_END
