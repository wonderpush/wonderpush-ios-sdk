//
//  WPSPISO8601Duration.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSPISO8601Duration : NSObject
@property (readonly) BOOL positive;
@property (nonnull, readonly) NSNumber *years;
@property (nonnull, readonly) NSNumber *months;
@property (nonnull, readonly) NSNumber *weeks;
@property (nonnull, readonly) NSNumber *days;
@property (nonnull, readonly) NSNumber *hours;
@property (nonnull, readonly) NSNumber *minutes;
@property (nonnull, readonly) NSNumber *seconds;

+ (instancetype) parse:(NSString *)input;

- (instancetype) initWithYears:(NSNumber *)years
                        months:(NSNumber *)months
                         weeks:(NSNumber *)weeks
                          days:(NSNumber *)days
                         hours:(NSNumber *)hours
                       minutes:(NSNumber *)minutes
                       seconds:(NSNumber *)seconds
                      positive:(BOOL)positive;

- (NSDate *)applyTo:(NSDate *)date;
@end

NS_ASSUME_NONNULL_END
