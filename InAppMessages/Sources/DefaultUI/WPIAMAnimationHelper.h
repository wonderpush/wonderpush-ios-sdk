//
//  WPIAMAnimationHelper.h
//  WonderPush
//
//  Created by Stéphane JAIS on 28/08/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPInAppMessagingRendering.h"
#import "WPIAMBaseRenderingViewController.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPIAMAnimationHelper : NSObject

+ (void)prepareEntryAnimation:(WPInAppMessagingEntryAnimation)animation
                       onView:(UIView *)view
                   controller:(WPIAMBaseRenderingViewController *)controller;

+ (void)executeEntryAnimation:(WPInAppMessagingEntryAnimation)animation
                       onView:(UIView *)view
                   controller:(WPIAMBaseRenderingViewController *)controller
                   completion:(nullable void(^)(BOOL complete))completion;
+ (void)executeExitAnimation:(WPInAppMessagingExitAnimation)animation
                      onView:(UIView *)view
                  controller:(WPIAMBaseRenderingViewController *)controller
                  completion:(nullable void(^)(BOOL complete))completion;

@end

NS_ASSUME_NONNULL_END
