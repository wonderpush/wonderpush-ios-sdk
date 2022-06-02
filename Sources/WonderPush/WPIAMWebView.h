//
//  WPIAMWebView.h
//  WonderPush
//
//  Created by Stéphane JAIS on 01/06/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <WonderPush/WonderPush.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMWebView : WKWebView
@property (nonatomic, strong, nullable) void(^onNavigationError)(NSError *);
@property (nonatomic, strong, nullable) void(^onNavigationSuccess)(WKWebView *);
@property (nonatomic, strong, nullable) void(^onDismiss)(WPInAppMessagingDismissType);
@end

NS_ASSUME_NONNULL_END
