//
//  WPRateLimiter.m
//  WonderPush
//
//  Created by Stéphane JAIS on 13/07/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPRateLimiter.h"
#import <WonderPushCommon/WPLog.h>

@interface WPRateLimit ()
@property (nonatomic, strong) NSString *key;
@property (nonatomic, assign) NSTimeInterval timeToLive;
@property (nonatomic, assign) NSUInteger limit;
@end

@interface WPRateLimiterData : NSObject<NSSecureCoding>
- (instancetype) initWithKey:(NSString *)key;
@property (readonly) NSString *key;
@property (readonly) NSMutableArray<NSDate *> *incrementDates;
- (void) removeIncrementsOlderThan:(NSTimeInterval)timeToLive;
@end

@interface WPRateLimiter ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, WPRateLimiterData *> *limiterData;
@end

@implementation WPRateLimit

- (instancetype)initWithKey:(NSString *)key timeToLive:(NSTimeInterval)timeToLive limit:(NSUInteger)limit {
    if (self = [super init]) {
        _key = key;
        _timeToLive = timeToLive;
        _limit = limit;
    }
    return self;
}

@end

@implementation WPRateLimiterData

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithKey:(NSString *)key {
    if (self = [super init]) {
        _key = key;
        _incrementDates = [NSMutableArray new];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _key = [coder decodeObjectOfClass:NSString.class forKey:@"key"];
        _incrementDates = [[coder decodeObjectOfClasses:[NSSet setWithObjects:NSArray.class, NSDate.class, nil] forKey:@"incrementDates"] mutableCopy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.key forKey:@"key"];
    [coder encodeObject:[NSArray arrayWithArray:self.incrementDates] forKey:@"incrementDates"];
}

- (void)removeIncrementsOlderThan:(NSTimeInterval)timeToLive {
    NSTimeInterval start = [NSDate date].timeIntervalSince1970 - timeToLive;
    while(_incrementDates.count > 0
          && _incrementDates[0].timeIntervalSince1970 < start) {
        [_incrementDates removeObjectAtIndex:0];
    }
}

@end

static WPRateLimiter *rateLimiter = nil;
#define WPRateLimiterUserDefaultsKey @"_WPRateLimiter"

@implementation WPRateLimiter

+ (instancetype)rateLimiter {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rateLimiter = [WPRateLimiter new];
    });
    return rateLimiter;
}

- (instancetype) init {
    if (self = [super init]) {
        _limiterData = [NSMutableDictionary new];
        NSArray *storedLimiterData = [NSUserDefaults.standardUserDefaults objectForKey:WPRateLimiterUserDefaultsKey];
        if (storedLimiterData) {
            for (NSData *data in storedLimiterData) {
                NSError *error = nil;
                WPRateLimiterData *limiterData = nil;
                if (@available(iOS 11.0, *)) {
                    limiterData = [NSKeyedUnarchiver unarchivedObjectOfClass:WPRateLimiterData.class fromData:data error:&error];
                } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    limiterData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
                }
                if (error) {
                    WPLog(@"Error unarchiving: %@", error);
                    continue;
                }
                if (limiterData) {
                    _limiterData[limiterData.key] = limiterData;
                }
            }
        }
    }
    return self;
}

- (void) save {
    @synchronized (self) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSMutableArray *limiterDataArray = [NSMutableArray new];
        for (WPRateLimiterData *limiterData in self.limiterData.allValues) {
            NSError *error = nil;
            NSData *archivedData = nil;
            if (@available(iOS 11.0, *)) {
                archivedData = [NSKeyedArchiver archivedDataWithRootObject:limiterData requiringSecureCoding:YES error:&error];
            } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                archivedData = [NSKeyedArchiver archivedDataWithRootObject:limiterData];
#pragma clang diagnostic pop
            }
            if (error) {
                NSLog(@"Error unarchiving: %@", error);
                continue;
            }
            if (archivedData) {
                [limiterDataArray addObject:archivedData];
            }
        }
        [defaults setObject:[NSArray arrayWithArray:limiterDataArray] forKey:WPRateLimiterUserDefaultsKey];
        [defaults synchronize];
    }
}

- (void) increment:(WPRateLimit *)rateLimit {
    @synchronized (self) {
        WPRateLimiterData *existingData = self.limiterData[rateLimit.key];
        WPRateLimiterData *data = existingData ?: [[WPRateLimiterData alloc] initWithKey:rateLimit.key];

        // Remove all dates prior to the rateLimit's timeToLive
        [data removeIncrementsOlderThan:rateLimit.timeToLive];

        // Increment
        [data.incrementDates addObject:[NSDate date]];

        // Store
        self.limiterData[data.key] = data;
        [self save];
    }
}

- (BOOL)isRateLimited:(WPRateLimit *)rateLimit {
    @synchronized (self) {
        WPRateLimiterData *data = self.limiterData[rateLimit.key];
        if (!data) return NO;
        // Remove all dates prior to the rateLimit's timeToLive
        [data removeIncrementsOlderThan:rateLimit.timeToLive];
        [self save];
        return data.incrementDates.count >= rateLimit.limit;
    }
}

- (void)clear:(WPRateLimit *)rateLimit {
    @synchronized (self) {
        [self.limiterData removeObjectForKey:rateLimit.key];
        [self save];
    }
}
@end
