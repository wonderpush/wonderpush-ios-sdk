//
//  WPNotificationServiceExtension.h
//  WonderPush
//
//  Created by Stéphane JAIS on 20/02/2019.
//  Copyright © 2019 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/**
 `WPNotificationServiceExtension` handles WonderPush rich push notifications. Subclass for easy integration, use static methods if you already have a UNNotificationServiceExtension.
 */
API_AVAILABLE(ios(10.0))
@interface WPNotificationServiceExtension : UNNotificationServiceExtension

/**
 Forwards a NotificationServiceExtension call to the SDK.
 
 Method to call in your `didReceiveNotificationRequest:withContentHandler:` method of your `NotificationService` extension.
 Pass `self` in the first argument.
 Calling this method from Swift is done like this: `Self.serviceExtension(self, didReceive: request, withContentHandler: contentHandler)`.
 
 @param extension Simply pass `self` from your `NotificationService` class.
 @param request Same parameter as in the forwarded protocol method.
 @param contentHandler Same parameter as in the forwarded protocol method.
 
 @return `YES` if the call was handled by WonderPush, `NO` otherwise.
 */
+ (BOOL)serviceExtension:(UNNotificationServiceExtension *)extension didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *contentToDeliver))contentHandler;

/**
 Forwards a NotificationServiceExtension call to the SDK.
 
 Method to call in your `serviceExtensionTimeWillExpire` method of your `NotificationService` extension.
 Pass `self` in the first argument.
 
 @param extension Simply pass `self` from your `NotificationService` class.
 
 @return `YES` if the call was handled by WonderPush, `NO` otherwise.
 */
+ (BOOL)serviceExtensionTimeWillExpire:(UNNotificationServiceExtension *)extension;

/**
 Override this method to provide your app's client ID.
 */
+ (NSString *)clientId;

/**
Override this method to provide your app's client secret.
*/
+ (NSString *)clientSecret;

@end

NS_ASSUME_NONNULL_END
