//
//  NotificationServiceExtension.m
//  WonderPushExtension
//
//  Created by Stéphane JAIS on 26/02/2019.
//  Copyright © 2019 WonderPush. All rights reserved.
//

#import "NotificationServiceExtension.h"

@implementation WPNotificationService
@end

@implementation WonderPushNotificationServiceExtension

+ (BOOL) serviceExtensionTimeWillExpire:(UNNotificationServiceExtension *)extension
{
    return [WPNotificationServiceExtension  serviceExtensionTimeWillExpire:extension];
}

+ (BOOL) serviceExtension:(UNNotificationServiceExtension *)extension didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler
{
    return [WPNotificationServiceExtension serviceExtension:extension didReceiveNotificationRequest:request withContentHandler:contentHandler];
}

@end
