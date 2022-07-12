//
//  WPIAMWebViewViewController.h
//  WonderPush
//
//  Created by Prouha Kévin on 03/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "WPIAMBaseRenderingViewController.h"

@class WPInAppMessagingImageOnlyDisplay;
@protocol WPIAMTimeFetcher;
@protocol WPInAppMessagingDisplayDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface WPIAMWebViewViewController : WPIAMBaseRenderingViewController
+ (WPIAMWebViewViewController *) instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                      displayMessage:(WPInAppMessagingWebViewDisplay *)webViewMessage
                                     controllerDelegate:(id<WPInAppMessagingControllerDelegate>)controllerDelegate
                                         timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher;
@end
NS_ASSUME_NONNULL_END
