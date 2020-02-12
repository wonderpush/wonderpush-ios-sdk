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

#import "WPIAMSDKSettings.h"

@implementation WPIAMSDKSettings

- (NSString *)description {
    return
    [NSString stringWithFormat:@"Activity Logger Max:%lu; "
     "Foreground Display Trigger Minimal Interval:%lu seconds;\n",
     (unsigned long)self.loggerMaxCountBeforeReduce,
     (unsigned long)(self.appFGRenderMinIntervalInMinutes * 60)];
}
@end
