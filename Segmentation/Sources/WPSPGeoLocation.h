//
//  WPSPGeoLocation.h
//  WonderPush
//
//  Created by Stéphane JAIS on 30/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSPGeoLocation : NSObject
@property (nonatomic, assign, readonly) double lat;
@property (nonatomic, assign, readonly) double lon;

- (instancetype) initWithLat:(double)lat lon:(double)lon;
@end

NS_ASSUME_NONNULL_END
