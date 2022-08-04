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

#import "WPIAMDisplayTriggerDefinition.h"

@implementation WPIAMDisplayTriggerDefinition
- (instancetype)initForAppLaunchTrigger {
    return [self initForAppLaunchTriggerDelay:0];
}
- (instancetype)initForAppForegroundTrigger {
    return [self initForAppForegroundTriggerDelay:0];

}
- (instancetype)initWithEvent:(NSString *)title minOccurrences:(NSNumber * _Nullable)minOccurrences {
    return [self initWithEvent:title minOccurrences:minOccurrences delay:0];
}

- (instancetype)initForAppLaunchTriggerDelay:(NSTimeInterval)delay {
    if (self = [super init]) {
        _triggerType = WPIAMRenderTriggerOnAppLaunch;
        _delay = delay;
        _minOccurrences = nil;
    }
    return self;
}

- (instancetype)initForAppForegroundTriggerDelay:(NSTimeInterval)delay {
    if (self = [super init]) {
        _triggerType = WPIAMRenderTriggerOnAppForeground;
        _delay = delay;
        _minOccurrences = nil;
    }
    return self;
}
- (instancetype)initWithEvent:(NSString *)title minOccurrences:(NSNumber * _Nullable)minOccurrences delay:(NSTimeInterval)delay {
    if (self = [super init]) {
        _triggerType = WPIAMRenderTriggerOnWonderPushEvent;
        _eventName = title;
        _delay = delay;
        _minOccurrences = minOccurrences;
    }
    return self;
}
@end
