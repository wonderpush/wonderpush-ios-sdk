//
//  WPPresenceManager.m
//  WonderPush
//
//  Created by Stéphane JAIS on 24/09/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPPresenceManager.h"

@implementation WPPresencePayload
- (instancetype) initWithFromDate:(NSDate *)fromDate untilDate:(NSDate *)untilDate {
    if (self = [super init]) {
        _fromDate = fromDate;
        _untilDate = untilDate;
        _elapsedTime = untilDate.timeIntervalSince1970 - fromDate.timeIntervalSince1970;
    }
    return self;
}
- (id) toJSON {
    return @{
        @"fromDate" : [NSNumber numberWithLong:(long)(self.fromDate.timeIntervalSince1970 * 1000)],
        @"untilDate" : [NSNumber numberWithLong:(long)(self.untilDate.timeIntervalSince1970 * 1000)],
        @"elapsedTime" : [NSNumber numberWithLong:(long)(self.elapsedTime * 1000)],
    };
}
@end

@interface WPPresenceManager ()
@property (nonatomic, strong, nullable) NSTimer *autoRenewTimer;
@property (nonatomic, strong, nullable) WPPresencePayload *lastPresencePayload;
- (void) extendPresence;
- (BOOL) autoRenew;
@end

@implementation WPPresenceManager

- (BOOL)autoRenew {
    if (self.autoRenewDelegate) return YES;
    return NO;
}

- (instancetype)initWithAutoRenewDelegate:(id<WPPresenceManagerAutoRenewDelegate>)autoRenewDelegate anticipatedTime:(NSTimeInterval)anticipatedTime safetyMarginTime:(NSTimeInterval)safetyMarginTime {
    if (self = [super init]) {
        _autoRenewDelegate = autoRenewDelegate;
        _anticipatedTime = anticipatedTime;
        _safetyMarginTime = MAX(0.1, safetyMarginTime); // minimum 100ms
    }
    return self;
}

- (WPPresencePayload *)presenceDidStart {
    [self.autoRenewTimer invalidate];
    if (self.autoRenew) {
        self.autoRenewTimer = [NSTimer
                               scheduledTimerWithTimeInterval:self.safetyMarginTime / 10
                               target:self
                               selector:@selector(extendPresence)
                               userInfo:nil
                               repeats:YES];
    }
    NSDate *startDate = [NSDate date];
    NSDate *untilDate = [startDate dateByAddingTimeInterval:self.anticipatedTime];
    self.lastPresencePayload = [[WPPresencePayload alloc] initWithFromDate:startDate untilDate:untilDate];
    return self.lastPresencePayload;
}

- (WPPresencePayload *)presenceWillStop {
    [self.autoRenewTimer invalidate];
    NSDate *now = [NSDate date];
    NSDate *fromDate = self.lastPresencePayload ? self.lastPresencePayload.fromDate : now;
    WPPresencePayload *payload = [[WPPresencePayload alloc] initWithFromDate:fromDate untilDate:now];
    self.lastPresencePayload = nil;
    return payload;
}

- (void)extendPresence {
    NSDate *now = [NSDate date];
    NSTimeInterval timeUntilPresenceEnds = self.lastPresencePayload ? [self.lastPresencePayload.untilDate timeIntervalSinceDate:now] : 0;
    
    // Not time to update yet.
    if (timeUntilPresenceEnds > self.safetyMarginTime) return;
    
    // Compute fromDate
    NSDate *fromDate;
    if (timeUntilPresenceEnds < 0) {
        // When we're past 'untilDate', it's a new presence. Override 'fromDate'
        fromDate = now;
    } else {
        fromDate = self.lastPresencePayload.fromDate ? self.lastPresencePayload.fromDate : now;

    }

    // Compute new 'untilDate'
    NSDate *untilDate = [now dateByAddingTimeInterval:self.anticipatedTime];

    // Payload
    self.lastPresencePayload = [[WPPresencePayload alloc] initWithFromDate:fromDate untilDate:untilDate];
    
    // Tell the delegate
    [self.autoRenewDelegate presenceManager:self wantsToRenewPresence:self.lastPresencePayload];

}

- (BOOL)isCurrentlyPresent {
    if (!self.lastPresencePayload) return NO;
    return [self.lastPresencePayload.untilDate timeIntervalSinceNow] > 0;
}

@end
