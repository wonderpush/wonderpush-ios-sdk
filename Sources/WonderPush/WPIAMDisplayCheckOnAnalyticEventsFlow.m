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
@property (atomic) BOOL started;
@end

static dispatch_queue_t eventListenerQueue;

@implementation WPIAMDisplayCheckOnAnalyticEventsFlow

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventListenerQueue = dispatch_queue_create("com.wonderpush.inappmessage.wpevent_listener", NULL);
    });
}

- (instancetype)initWithDisplayFlow:(WPIAMDisplayExecutor *)displayExecutor {
    self = [super initWithDisplayFlow:displayExecutor];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventFired:) name:WPEventFiredNotification object:nil];
    }
    return self;
}

- (void)start {
    self.started = YES;
}

- (void)eventFired:(NSNotification *)notification {
    if (!self.started) {
        return;
    }
    NSString *eventType = notification.userInfo[WPEventFiredNotificationEventTypeKey];
    NSDictionary *occurrences = notification.userInfo[WPEventFiredNotificationEventOccurrencesKey];
    NSInteger allTimeOccurrences = [occurrences[@"allTime"] integerValue] ?: 1;
    dispatch_async(eventListenerQueue, ^{
      [self.displayExecutor
       checkAndDisplayNextContextualMessageForWonderPushEvent:eventType
       allTimeOccurrences: allTimeOccurrences];
    });
}

- (void)stop {
    self.started = NO;
}

@end
