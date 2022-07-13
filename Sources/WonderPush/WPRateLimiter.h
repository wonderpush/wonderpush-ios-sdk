//
//  WPRateLimiter.h
//  WonderPush
//
//  Created by Stéphane JAIS on 13/07/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPRateLimit : NSObject
@property (readonly) NSString *key;
@property (readonly) NSTimeInterval timeToLive;
@property (readonly) NSUInteger limit;
- (instancetype) initWithKey:(NSString *)key timeToLive:(NSTimeInterval)timeToLive limit:(NSUInteger)limit;
@end

@interface WPRateLimiter : NSObject
- (void) increment:(WPRateLimit *)rateLimit;
- (BOOL) isRateLimited:(WPRateLimit *)rateLimit;
- (void) clear:(WPRateLimit *)rateLimit;
+ (instancetype) rateLimiter;
@end

NS_ASSUME_NONNULL_END
