//
//  WPIAMWkWebViewPreloaderController.h
//  WonderPush
//
//  Created by Prouha Kévin on 19/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <WonderPush/InAppMessaging.h>
NS_ASSUME_NONNULL_BEGIN

@interface WPIAMWebViewPreloaderViewController : UIViewController
- (void) preLoadWebViewWithURL:(NSURL *)webViewURL
      successCompletionHandler:(void (^)(WKWebView*))successBlock
         errorCompletionHander:(void (^)(NSError *)) errorBlock;
@end

NS_ASSUME_NONNULL_END
