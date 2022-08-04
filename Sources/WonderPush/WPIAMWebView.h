//
//  WPIAMWebView.h
//  WonderPush
//
//  Created by Stéphane JAIS on 01/06/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <WonderPush/WonderPush.h>
#import "WPIAMBaseRenderingViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMWebView : WKWebView
+ (void) ensureInitialized;
@property (nonatomic, weak, nullable) id<WPInAppMessagingControllerDelegate> controllerDelegate;
@property (nonatomic, weak, nullable) WPInAppMessagingDisplayMessage * inAppMessage;
@property (nonatomic, strong, nullable) void(^onNavigationError)(NSError *);
@property (nonatomic, strong, nullable) void(^onNavigationSuccess)(WKWebView *);
@property (nonatomic, strong, nullable) void(^onDismiss)(WPInAppMessagingDismissType);
@end

NS_ASSUME_NONNULL_END
