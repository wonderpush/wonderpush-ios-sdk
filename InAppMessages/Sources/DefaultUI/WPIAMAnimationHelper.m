//
//  WPIAMAnimationHelper.m
//  WonderPush
//
//  Created by Stéphane JAIS on 28/08/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPIAMAnimationHelper.h"

@implementation WPIAMAnimationHelper
+ (void)prepareEntryAnimation:(WPInAppMessagingEntryAnimation)animation
                       onView:(UIView *)view
                   controller:(WPIAMBaseRenderingViewController *)controller {
    switch (animation) {
        case WPInAppMessagingEntryAnimationFadeIn:
            view.alpha = 0;
            break;
        case WPInAppMessagingEntryAnimationSlideInFromTop: {
            view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y - controller.view.frame.size.height, view.frame.size.width, view.frame.size.height);
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromRight:
        case WPInAppMessagingEntryAnimationSlideInFromBottom:
        case WPInAppMessagingEntryAnimationSlideInFromLeft:
        case WPInAppMessagingEntryAnimationScaleUp:
            break;
    }
    
}
+ (void)executeEntryAnimation:(WPInAppMessagingEntryAnimation)animation
                       onView:(UIView *)view
                   controller:(WPIAMBaseRenderingViewController *)controller
                   completion:(nullable void (^)(BOOL))completion {
    switch (animation) {
        case WPInAppMessagingEntryAnimationFadeIn: {
            [UIView animateWithDuration:0.25f animations:^{
                view.alpha = 1;
            } completion:completion];
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromTop: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y + controller.view.frame.size.height, view.frame.size.width, view.frame.size.height);

            } completion:completion];
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromRight:
        case WPInAppMessagingEntryAnimationSlideInFromBottom:
        case WPInAppMessagingEntryAnimationSlideInFromLeft:
        case WPInAppMessagingEntryAnimationScaleUp:
            if (completion) completion(YES);
            break;
    }

    
}
+ (void)executeExitAnimation:(WPInAppMessagingExitAnimation)animation
                      onView:(UIView *)view
                  controller:(WPIAMBaseRenderingViewController *)controller
                  completion:(nullable void (^)(BOOL))completion {
    switch (animation) {
        case WPInAppMessagingExitAnimationFadeOut: {
            [UIView animateWithDuration:0.25f animations:^{
                view.alpha = 0;
            } completion:completion];
        }
            break;
        case WPInAppMessagingExitAnimationSlideOutUp: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y - controller.view.frame.size.height, view.frame.size.width, view.frame.size.height);

            } completion:completion];
        }
            break;
        case WPInAppMessagingExitAnimationSlideOutRight:
        case WPInAppMessagingExitAnimationSlideOutDown:
        case WPInAppMessagingExitAnimationSlideOutLeft:
        case WPInAppMessagingExitAnimationScaleDown:
            if (completion) completion(YES);
            break;
    }
}
@end
