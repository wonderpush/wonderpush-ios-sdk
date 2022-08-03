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

- (void)loadView {
    [super loadView];
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.allowsInlineMediaPlayback = YES;
    configuration.applicationNameForUserAgent = @"WonderPushInAppSDK";
    // Seems like this is the only way to have the applicationNameForUserAgent setting working
    WPIAMWebView *webView = [[WPIAMWebView alloc] initWithFrame:self.view.frame configuration:configuration];
    [self.view addSubview:webView];
    self.webView = webView;
    self.webView.opaque = false;
    self.webView.backgroundColor = UIColor.clearColor;
    self.webView.scrollView.backgroundColor = UIColor.clearColor;
}

- (void) preLoadWebViewWithURL: (NSURL *) webViewURL successCompletionHandler: (void (^)(WKWebView*)) successBlock errorCompletionHander: (void (^)(NSError *)) errorBlock {

    //Loads the view controller's view if it has not yet been loaded.
    [self loadViewIfNeeded];

    self.webView.onNavigationSuccess = successBlock;
    self.webView.onNavigationError = errorBlock;
    NSURLRequest *requestToLoad = [NSURLRequest requestWithURL: webViewURL];
    [self.webView loadRequest:requestToLoad];
}


@end
