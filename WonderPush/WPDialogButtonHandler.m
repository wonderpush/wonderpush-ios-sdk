/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "WPDialogButtonHandler.h"
#import "WonderPush_private.h"

@implementation WPDialogButtonHandler

@synthesize buttonConfiguration, notificationConfiguration, showTime;

- (id)init
{
    self = [super init];
    if (self) {
        self.showTime = [[NSProcessInfo processInfo] systemUptime];
    }
    return self;
}

- (void)executeButtonActions:(NSArray *) actions
{
    if (!actions) return;
    for (NSDictionary *action in actions)
    {
        [WonderPush executeAction:action onNotification:notificationConfiguration];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    NSDictionary *clickedButton = nil;
    if (buttonConfiguration && buttonIndex >= 0 && buttonIndex < buttonConfiguration.count) {
        clickedButton = [buttonConfiguration objectAtIndex:buttonIndex];
    }

    NSNumber *shownTime = [[NSNumber alloc] initWithLong:(long)(([[NSProcessInfo processInfo] systemUptime] - self.showTime) * 1000)];
    [WonderPush trackInternalEvent:@"@NOTIFICATION_ACTION"
                         eventData:@{@"buttonLabel":[clickedButton objectForKey:@"label"] ?: [NSNull null],
                                     @"reactionTime":shownTime}
                        customData:nil];

    NSArray *clickedButtonAction = [clickedButton objectForKey:@"actions"];
    [self executeButtonActions:clickedButtonAction];
    [WonderPush resetButtonHandler];
}

- (void)customIOS7dialogButtonTouchUpInside: (CustomIOS7AlertView *)alertView clickedButtonAtIndex: (NSInteger)buttonIndex
{
    [self alertView:nil clickedButtonAtIndex:buttonIndex];
    [alertView close];
}

@end
