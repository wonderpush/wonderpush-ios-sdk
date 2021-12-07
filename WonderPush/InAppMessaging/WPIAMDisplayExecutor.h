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

#import <Foundation/Foundation.h>

#import "WPIAMBookKeeper.h"
#import "WPIAMMessageClientCache.h"
#import "WPIAMTimeFetcher.h"
#import <WonderPush/WPInAppMessaging.h>
#import <WonderPush/WPInAppMessagingRendering.h>

NS_ASSUME_NONNULL_BEGIN
@interface WPIAMDisplaySetting : NSObject
@property(nonatomic) NSTimeInterval displayMinIntervalInMinutes;
@end

// The class for checking if there are appropriate messages to be displayed and if so, render it.
// There are other flows that would determine the timing for the checking and then use this class
// instance for the actual check/display.
//
// In addition to fetch eligible message from message cache, this class also ensures certain
// conditions are satisfied for the rendering
//   1 No current in-app message is being displayed
//   2 For non-contextual messages, the display interval in display setting is met.
@interface WPIAMDisplayExecutor : NSObject

- (instancetype)initWithInAppMessaging:(WPInAppMessaging *)inAppMessaging
                               setting:(WPIAMDisplaySetting *)setting
                          messageCache:(WPIAMMessageClientCache *)cache
                           timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher
                            bookKeeper:(id<WPIAMBookKeeper>)displayBookKeeper;

// Check and display next in-app message eligible for app launch trigger
- (void)checkAndDisplayNextAppLaunchMessage;
// Check and display next in-app message eligible for app open trigger
- (void)checkAndDisplayNextAppForegroundMessage;
// Check and display next in-app message eligible for analytics event trigger with given event name.
- (void)checkAndDisplayNextContextualMessageForWonderPushEvent:(NSString *)eventName;
// Force display a message now
- (void)displayMessage:(WPIAMMessageDefinition *)message
              triggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                    delay:(NSTimeInterval)delay;
// a boolean flag that can be used to suppress/resume displaying messages.
@property(nonatomic) BOOL suppressMessageDisplay;

// This is the display component used by display executor for actual message rendering.
@property(nonatomic) id<WPInAppMessagingDisplay> messageDisplayComponent;
@end
NS_ASSUME_NONNULL_END
