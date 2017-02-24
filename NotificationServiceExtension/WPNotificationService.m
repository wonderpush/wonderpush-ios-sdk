/*
 Copyright 2017 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "NotificationServiceExtension.h"

@implementation WPNotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    // Forward the call to the WonderPush NotificationServiceExtension SDK
    if (![WonderPushNotificationServiceExtension serviceExtension:self didReceiveNotificationRequest:request withContentHandler:contentHandler]) {
        // The notification was not for the WonderPush SDK consumption, handle it ourself
        contentHandler(request.content);
    }
}

- (void)serviceExtensionTimeWillExpire {
    // Forward the call to the WonderPush NotificationServiceExtension SDK
    [WonderPushNotificationServiceExtension serviceExtensionTimeWillExpire:self];
    // If the notification was not for the WonderPush SDK consumption,
    // we would have handled it ourself, and we would never enter this function.
}

@end
