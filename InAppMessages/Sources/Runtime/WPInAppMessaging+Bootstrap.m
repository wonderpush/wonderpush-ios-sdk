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

#import "WPInAppMessaging+Bootstrap.h"
#import "WPCore+InAppMessaging.h"
#import "WPIAMRuntimeManager.h"
#import "WPIAMSDKSettings.h"
#import "NSString+WPInterlaceStrings.h"

@implementation WPInAppMessaging (Bootstrap)

static WPIAMSDKSettings *_sdkSetting = nil;

+ (void)bootstrapIAMWithSettings:(WPIAMSDKSettings *)settings {
    _sdkSetting = settings;
    [[WPIAMRuntimeManager getSDKRuntimeInstance] startRuntimeWithSDKSettings:_sdkSetting];
}

+ (void)pause {
    [[WPIAMRuntimeManager getSDKRuntimeInstance] pause];
}

+ (void)resume {
    [[WPIAMRuntimeManager getSDKRuntimeInstance] resume];
}

+ (void)exitAppWithFatalError:(NSError *)error {
    [NSException raise:kWonderPushInAppMessagingErrorDomain
                format:@"Error happened %@", error.localizedDescription];
}

@end
