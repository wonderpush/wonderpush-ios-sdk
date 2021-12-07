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
        case WPInAppMessagingEntryAnimationSlideInFromBottom: {
            view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y + controller.view.frame.size.height, view.frame.size.width, view.frame.size.height);
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromLeft: {
            view.frame = CGRectMake(view.frame.origin.x - controller.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromRight: {
            view.frame = CGRectMake(view.frame.origin.x + controller.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
        }
            break;
        default:
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
        case WPInAppMessagingEntryAnimationSlideInFromBottom: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y - controller.view.frame.size.height, view.frame.size.width, view.frame.size.height);
            } completion:completion];
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromLeft: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x + controller.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
            } completion:completion];
        }
            break;
        case WPInAppMessagingEntryAnimationSlideInFromRight: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x - controller.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
            } completion:completion];
        }
            break;
        default:
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
        case WPInAppMessagingExitAnimationSlideOutDown: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y + controller.view.frame.size.height, view.frame.size.width, view.frame.size.height);
            } completion:completion];
        }
            break;
        case WPInAppMessagingExitAnimationSlideOutLeft: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x - controller.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
            } completion:completion];
        }
            break;
        case WPInAppMessagingExitAnimationSlideOutRight: {
            [UIView animateWithDuration:0.3f animations:^{
                view.frame = CGRectMake(view.frame.origin.x + controller.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
            } completion:completion];
        }
            break;
        default:
            if (completion) completion(YES);
            break;
    }
}
@end
