//
//  WPIAMWkWebViewPreloaderController.m
//  WonderPush
//
//  Created by Prouha Kévin on 19/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPIAMWebViewPreloaderViewController.h"
#import "WPLog.h"
#import "WonderPush_constants.h"
#import "WPCore+InAppMessagingDisplay.h"
#import "WPInAppMessagingRendering.h"
#import "WPIAMWebView.h"
@interface WPIAMWebViewPreloaderViewController () <WKNavigationDelegate>
@property (weak, nonatomic) IBOutlet WPIAMWebView *webView;

@end


@implementation WPIAMWebViewPreloaderViewController

- (void)viewDidLoad {
    self.webView.opaque = false;
    self.webView.backgroundColor = UIColor.clearColor;
    self.webView.scrollView.backgroundColor = UIColor.clearColor;
    if (@available(iOS 11.0, *)) {
        // Make sure the HTML content extends to the entire view
        // This seems to fix a problem where fullscreen HTML content is not reaching the bottom of the screen by as many pixels as both top and bottom safe area heights combined.
        [self.webView.scrollView setContentInsetAdjustmentBehavior: UIScrollViewContentInsetAdjustmentNever];
    }
}

- (void) preLoadWebViewWith: (NSURL *) webViewURL withSuccessCompletionHandler: (void (^)(WKWebView*)) successBlock withErrorCompletionHander: (void (^)(NSError *)) errorBlock {
    
    //Loads the view controller’s view if it has not yet been loaded.
    [self loadViewIfNeeded];
    
    self.webView.onNavigationSuccess = successBlock;
    self.webView.onNavigationError = errorBlock;
    NSURLRequest *requestToLoad = [NSURLRequest requestWithURL: webViewURL];
    [self.webView loadRequest:requestToLoad];
}


@end
