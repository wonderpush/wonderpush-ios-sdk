//
//  WPPresenceManager.h
//  WonderPush
//
//  Created by Stéphane JAIS on 24/09/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPPresencePayload : NSObject
@property (readonly) NSDate *fromDate;
@property (readonly) NSDate *untilDate;
@property (readonly) NSTimeInterval elapsedTime;
- (instancetype) initWithFromDate:(NSDate *)fromDate untilDate:(NSDate *)untilDate;
- (id) toJSON;
@end

@class WPPresenceManager;

@protocol WPPresenceManagerAutoRenewDelegate <NSObject>
- (void) presenceManager:(WPPresenceManager *)presenceManager wantsToRenewPresence:(WPPresencePayload *)presence;
@end

@interface WPPresenceManager : NSObject
@property (nonatomic, weak) id<WPPresenceManagerAutoRenewDelegate> autoRenewDelegate;
@property (readonly) NSTimeInterval anticipatedTime;
@property (readonly) NSTimeInterval safetyMarginTime;

- (instancetype) init NS_UNAVAILABLE;
/**
 @param autoRenewDelegate An object capable of sending presence payloads. When non nil, presence will auto-renew when we're safetyMarginTime away from absence time.
 @param anticipatedTime A time interval used to compute untilDate of the presence.
 @param safetyMarginTime A time interval used to trigger auto-renewal of the presence.
 */
- (instancetype) initWithAutoRenewDelegate:(nullable id<WPPresenceManagerAutoRenewDelegate>)autoRenewDelegate
                           anticipatedTime:(NSTimeInterval)anticipatedTime
                          safetyMarginTime:(NSTimeInterval)safetyMarginTime NS_DESIGNATED_INITIALIZER;

/**
 Declare that presence started.
 @return A presence payload to send, or nil
 */
- (WPPresencePayload *) presenceDidStart;

/**
 Declare that presence stopped.
 @return A presence payload to send, or nil
 */
- (WPPresencePayload *) presenceWillStop;

- (BOOL) isCurrentlyPresent;
@end

NS_ASSUME_NONNULL_END
