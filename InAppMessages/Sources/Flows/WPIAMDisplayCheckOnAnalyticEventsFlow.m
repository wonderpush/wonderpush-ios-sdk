/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "WPCore+InAppMessaging.h"
#import "WPIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "WPIAMDisplayExecutor.h"
#import "WPInAppMessagingPrivate.h"
#import "WonderPush_private.h"

@interface WPIAMDisplayCheckOnAnalyticEventsFlow ()
@end

@implementation WPIAMDisplayCheckOnAnalyticEventsFlow {
    dispatch_queue_t eventListenerQueue;
}

- (void)start {
    @synchronized(self) {
//        WPLogDebug(@"Start observing events for rendering messages.");
        if (eventListenerQueue == nil) {
          eventListenerQueue =
              dispatch_queue_create("com.wonderpush.inappmessage.wpevent_listener", NULL);
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventFired:) name:WPEventFiredNotification object:nil];
        
    }
}

- (void)eventFired:(NSNotification *)notification {
    NSString *eventType = [notification.userInfo objectForKey:WPEventFiredNotificationEventTypeKey];
    dispatch_async(self->eventListenerQueue, ^{
      [self.displayExecutor checkAndDisplayNextContextualMessageForWonderPushEvent:eventType];
    });
}

- (void)stop {
    @synchronized(self) {
//        WPLogDebug(@"Stop observing events for display check.");
    }
}

@end
