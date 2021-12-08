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
#import "WPIAMRenderingEffectSetting.h"

@implementation WPIAMRenderingEffectSetting

+ (instancetype)getDefaultRenderingEffectSetting {
    WPIAMRenderingEffectSetting *setting = [[WPIAMRenderingEffectSetting alloc] init];
    
    setting.btnBGColor = [UIColor colorWithWhite:1 alpha:0];
    setting.displayBGColor = [UIColor whiteColor];
    setting.textColor = [UIColor blackColor];
    setting.btnTextColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
    setting.autoDimissBannerAfterNSeconds = 12;
    setting.isTestMessage = NO;
    return setting;
}
@end
