//
//  WPNotificationCategoryManager.h
//  WonderPush
//
//  Created by Stéphane JAIS on 24/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPNotificationCategoryManager : NSObject
+ (instancetype) sharedInstance;
/**
 Returns an action identifier for the button at provided index
 */
- (NSString *)actionIdentifierForButtonAtIndex:(NSUInteger)index;
/**
 Creates and register a UNNotificationCategory for the provided notificationId and actions
 */
- (UNNotificationCategory *_Nullable) registerNotificationCategoryIdentifierWithNotificationId:(NSString *)notificationId actions:(NSArray<UNNotificationAction *> *)actions API_AVAILABLE(ios(10.0));
@end
NS_ASSUME_NONNULL_END
