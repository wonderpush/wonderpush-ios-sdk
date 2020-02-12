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
#import "WPIAMDisplayCheckOnAppForegroundFlow.h"
#import "WPIAMDisplayExecutor.h"

@implementation WPIAMDisplayCheckOnAppForegroundFlow

- (void)start {
    WPLogDebug(
                @"Start observing app foreground notifications for rendering messages.");
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(checkAndDisplayNextAppForegroundMessageFromForeground:)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (@available(iOS 13.0, *)) {
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(checkAndDisplayNextAppForegroundMessageFromForeground:)
         name:UISceneWillEnterForegroundNotification
         object:nil];
    }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
}

- (void)checkAndDisplayNextAppForegroundMessageFromForeground:(NSNotification *)notification {
    WPLogDebug(
                @"App foregrounded, wake up to check in-app messaging.");
    
    // Call checkAndDisplayNextAppForegroundMessage immediately if app is active
    // or next time it becomes active. We have to be on the main thread to check the application state.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
        } else {
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            __block id observer;
            void(^block)(NSNotification *) = ^(NSNotification *note) {
                [center removeObserver:observer];
                [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
            };
            observer = [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:block];
        }
    });
}

- (void)stop {
    WPLogDebug(
                @"Stop observing app foreground notifications.");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
