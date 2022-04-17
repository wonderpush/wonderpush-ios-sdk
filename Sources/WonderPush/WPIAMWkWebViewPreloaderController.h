//
//  WPIAMWkWebViewPreloaderController.h
//  WonderPush
//
//  Created by Prouha Kévin on 19/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMWkWebViewPreloaderController : UIViewController
- (void) preLoadWebViewWith : (NSURL *) webViewURL
                           withSuccessCompletionHandler : (void (^)(WKWebView*)) successBlock
                           withErrorCompletionHander: (void (^)(NSError *)) errorBlock;
@end

NS_ASSUME_NONNULL_END
