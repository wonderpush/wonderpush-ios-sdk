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

typedef NS_ENUM(NSInteger, WPIAMRenderTrigger) {
  WPIAMRenderTriggerOnAppLaunch,
  WPIAMRenderTriggerOnAppForeground,
  WPIAMRenderTriggerOnWonderPushEvent
};

NS_ASSUME_NONNULL_BEGIN
@interface WPIAMDisplayTriggerDefinition : NSObject
@property(nonatomic, readonly) WPIAMRenderTrigger triggerType;

// applicable only when triggerType == WPIAMRenderTriggerOnWonderPushEvent
@property(nonatomic, copy, nullable, readonly) NSString *eventName;
@property(nonatomic, copy, nullable, readonly) NSNumber *minOccurrences;
@property(nonatomic, readonly) NSTimeInterval delay; // In seconds

- (instancetype)initForAppLaunchTrigger;
- (instancetype)initForAppForegroundTrigger;
- (instancetype)initWithEvent:(NSString *)title minOccurrences:(NSNumber * _Nullable)minOccurrences;

- (instancetype)initForAppLaunchTriggerDelay:(NSTimeInterval)delay;
- (instancetype)initForAppForegroundTriggerDelay:(NSTimeInterval)delay;
- (instancetype)initWithEvent:(NSString *)title minOccurrences:(NSNumber * _Nullable)minOccurrences delay:(NSTimeInterval)delay;
@end
NS_ASSUME_NONNULL_END
