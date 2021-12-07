//
//  WPSPISO8601Duration.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPISO8601Duration.h"
#import <WonderPushCommon/WPLog.h>
#import "WPSPExceptions.h"

@implementation WPSPISO8601Duration

+ (NSRegularExpression *) regularExpression {
    static dispatch_once_t onceToken;
    static NSRegularExpression *rtn;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        NSString *pattern = @"^([+-])?P(\\d+(?:(?:[.,])\\d*)?Y)?(\\d+(?:(?:[.,])\\d*)?M)?(\\d+(?:(?:[.,])\\d*)?W)?(\\d+(?:(?:[.,])\\d*)?D)?(?:T(\\d+(?:(?:[.,])\\d*)?H)?(\\d+(?:(?:[.,])\\d*)?M)?(\\d+(?:(?:[.,])\\d*)?S)?)?$";
        rtn = [NSRegularExpression regularExpressionWithPattern:pattern
                                                        options:0
                                                          error:&error];
        if (error) {
            WPLog(@"Error creating regular expression: %@", error);
        }
    });
    return rtn;
}

+ (NSCalendar *)calendar {
    static NSCalendar *gregorianCalendar = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        gregorianCalendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    });
    return gregorianCalendar;
}

+ (instancetype)parse:(NSString *)input {
    if (!input) @throw [WPSPBadInputException new];
    
    NSArray *matches = [self.regularExpression
                        matchesInString:input
                        options:NSMatchingAnchored range:NSMakeRange(0, input.length)];
    if (matches.count != 1) @throw [WPSPBadInputException new];
    
    NSTextCheckingResult *match = matches.firstObject;
    
    NSRange range = [match rangeAtIndex:1];
    BOOL positive = (range.location == NSNotFound) || ![@"-" isEqualToString:[input substringWithRange:range]];
    
    NSNumber *years = [self getPart:match group:2 input:input];
    NSNumber *months = [self getPart:match group:3 input:input];
    NSNumber *weeks = [self getPart:match group:4 input:input];
    NSNumber *days = [self getPart:match group:5 input:input];
    NSNumber *hours = [self getPart:match group:6 input:input];
    NSNumber *minutes = [self getPart:match group:7 input:input];
    NSNumber *seconds = [self getPart:match group:8 input:input];
    
    return [[self alloc] initWithYears:years months:months weeks:weeks days:days hours:hours minutes:minutes seconds:seconds positive:positive];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) return NO;
    WPSPISO8601Duration *other = object;
    return [self.years isEqual:other.years]
    && [self.months isEqual:other.months]
    && [self.weeks isEqual:other.weeks]
    && [self.days isEqual:other.days]
    && [self.hours isEqual:other.hours]
    && [self.minutes isEqual:other.minutes]
    && [self.seconds isEqual:other.seconds];
}

+ (NSNumber *)getPart:(NSTextCheckingResult *)match group:(NSInteger)group input:(NSString *)input {
    NSRange range = [match rangeAtIndex:group];
    if (range.location == NSNotFound) return @0;
    
    NSString *text = [input substringWithRange:NSMakeRange(range.location, range.length - 1)]; // Get the numeric text (remove the letter)
    text = [text stringByReplacingOccurrencesOfString:@"," withString:@"."];
    return [NSNumber numberWithDouble:text.doubleValue];
}

- (instancetype) initWithYears:(NSNumber *)years months:(NSNumber *)months weeks:(NSNumber *)weeks days:(NSNumber *)days hours:(NSNumber *)hours minutes:(NSNumber *)minutes seconds:(NSNumber *)seconds positive:(BOOL)positive {
    if (self = [super init]) {
        _years = years;
        _months = months;
        _weeks = weeks;
        _days = days;
        _hours = hours;
        _minutes = minutes;
        _seconds = seconds;
        _positive = positive;
    }
    return self;
}

- (NSDate *) applyTo:(NSDate *)date {
    NSCalendar *calendar = self.class.calendar;

    NSInteger sign = self.positive ? 1 : -1;
    double remainder = 0;
    
    NSInteger yearsInt = (self.years.doubleValue + remainder);
    date = [calendar dateByAddingUnit:NSCalendarUnitYear value:sign * yearsInt toDate:date options:0];
    remainder = self.years.doubleValue + remainder - yearsInt;
    remainder *= 12;
    
    NSInteger monthsInt = self.months.doubleValue + remainder;
    date = [calendar dateByAddingUnit:NSCalendarUnitMonth value:sign * monthsInt toDate:date options:0];
    remainder = self.months.doubleValue + remainder - monthsInt;
    
    remainder *= [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:date].length;

    NSInteger daysInt = self.days.doubleValue + self.weeks.doubleValue * 7 + remainder;
    date = [calendar dateByAddingUnit:NSCalendarUnitDay value:sign * daysInt toDate:date options:0];
    remainder = self.days.doubleValue + self.weeks.doubleValue * 7 + remainder - daysInt;
    remainder *= 24;
    
    NSInteger hoursInt = self.hours.doubleValue + remainder;
    date = [calendar dateByAddingUnit:NSCalendarUnitHour value:sign * hoursInt toDate:date options:0];
    remainder = self.hours.doubleValue + remainder - hoursInt;
    remainder *= 60;
    
    NSInteger minutesInt = self.minutes.doubleValue + remainder;
    date = [calendar dateByAddingUnit:NSCalendarUnitMinute value:sign * minutesInt toDate:date options:0];
    remainder = self.minutes.doubleValue + remainder - minutesInt;
    remainder *= 60;
    
    NSInteger secondsInt = self.seconds.doubleValue + remainder;
    date = [calendar dateByAddingUnit:NSCalendarUnitSecond value:sign * secondsInt toDate:date options:0];
    remainder = self.seconds.doubleValue + remainder - secondsInt;
    remainder *= 1000000000;
    
    NSInteger nanosecondsInt = round(remainder);
    date = [calendar dateByAddingUnit:NSCalendarUnitNanosecond value:sign * nanosecondsInt toDate:date options:0];
    return date;
}

@end
