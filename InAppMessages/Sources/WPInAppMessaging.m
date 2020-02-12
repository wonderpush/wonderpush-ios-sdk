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

#import "WPInAppMessaging.h"

#import <Foundation/Foundation.h>

#import "WPCore+InAppMessaging.h"
#import "WPIAMDisplayExecutor.h"
#import "WPIAMRuntimeManager.h"
#import "WPInAppMessaging+Bootstrap.h"
#import "WPInAppMessagingPrivate.h"

@implementation WPInAppMessaging {
    BOOL _messageDisplaySuppressed;
}

- (instancetype) init {
    if (self = [super init]) {
        _messageDisplaySuppressed = NO;
    }
    return self;
}

+ (WPInAppMessaging *)inAppMessaging {
    static WPInAppMessaging *inAppMessaging = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inAppMessaging = [WPInAppMessaging new];
    });
    return inAppMessaging;
}

- (BOOL)messageDisplaySuppressed {
    return _messageDisplaySuppressed;
}

- (void)setMessageDisplaySuppressed:(BOOL)suppressed {
    _messageDisplaySuppressed = suppressed;
    [[WPIAMRuntimeManager getSDKRuntimeInstance] setShouldSuppressMessageDisplay:suppressed];
}

- (void)setMessageDisplayComponent:(id<WPInAppMessagingDisplay>)messageDisplayComponent {
    _messageDisplayComponent = messageDisplayComponent;
    
    if (messageDisplayComponent == nil) {
        WPLogDebug(@"messageDisplayComponent set to nil.");
    } else {
        WPLogDebug(
                    @"Setting a non-nil message display component");
    }
    
    // Forward the setting to the display executor.
    [WPIAMRuntimeManager getSDKRuntimeInstance].displayExecutor.messageDisplayComponent =
    messageDisplayComponent;
}

@end
