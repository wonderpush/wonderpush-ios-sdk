//
//  WPIAMWebViewViewController.m
//  WonderPush
//
//  Created by Prouha Kévin on 03/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "WPIAMWebViewViewController.h"
#import "WPCore+InAppMessagingDisplay.h"
#import "WPIAMHitTestDelegateView.h"
#import "WPIAMWebView.h"
#import "WonderPush_constants.h"
#import "WPInAppMessagingRenderingPrivate.h"

@interface WPIAMWebViewViewController ()

@property(nonatomic, readwrite) WPInAppMessagingWebViewDisplay *webViewMessage;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet WKWebView *webView;
@end

@implementation WPIAMWebViewViewController 

+ (WPIAMWebViewViewController *) instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                      displayMessage:(WPInAppMessagingWebViewDisplay *)webViewMessage
                                     controllerDelegate:(id<WPInAppMessagingControllerDelegate>)controllerDelegate
                                         timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"WPInAppMessageDisplayStoryboard"
                                                         bundle:resourceBundle];
    if (storyboard == nil) {
        WPLog(@"Storyboard 'WPInAppMessageDisplayStoryboard' not found in bundle %@", resourceBundle);
        return nil;
    }
    WPIAMWebViewViewController *webViewVC = (WPIAMWebViewViewController *)[storyboard
                                                                           instantiateViewControllerWithIdentifier:@"webview-vc"];
    webViewVC.controllerDelegate = controllerDelegate;
    webViewVC.webViewMessage = webViewMessage;
    webViewVC.timeFetcher = timeFetcher;
    webViewVC.webView = webViewMessage.webView;
    return webViewVC;
}

- (WPInAppMessagingDisplayMessage *)inAppMessage {
    return self.webViewMessage;
}

- (IBAction)closeButtonClicked:(id)sender {
    [self dismissView:WPInAppMessagingDismissTypeUserTapClose];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!self.webView) {
        [self dismissView:WPInAppMessagingDismissUnspecified];
        return;
    }

    [self.view setBackgroundColor:UIColor.clearColor];

    if ([self.webView isKindOfClass:WPIAMWebView.class]) {
        __weak WPIAMWebView *webView = (WPIAMWebView *)self.webView;
        __weak WPIAMWebViewViewController *weakSelf = self;
        webView.controllerDelegate = self.controllerDelegate;
        webView.inAppMessage = self.inAppMessage;
        webView.onDismiss = ^(WPInAppMessagingDismissType type) {
            [weakSelf dismissView:type];
            webView.onDismiss = nil;
        };
    }

    self.webView.translatesAutoresizingMaskIntoConstraints = YES;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.containerView insertSubview:self.webView belowSubview:self.closeButton];
    self.containerView.frame = self.view.bounds;
    self.webView.frame = self.containerView.bounds;

    if (self.webViewMessage.closeButtonPosition == WPInAppMessagingCloseButtonPositionNone){
        self.closeButton.hidden = YES;
    } else {
        self.closeButton.hidden = NO;
    }
}

- (void)flashCloseButton:(UIButton *)closeButton {
    closeButton.alpha = 1.0f;
    [UIView animateWithDuration:2.0
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionRepeat |
     UIViewAnimationOptionAutoreverse |
     UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        closeButton.alpha = 0.1f;
    }
                     completion:^(BOOL finished){
        // Do nothing
    }];
}

- (UIView *)viewToAnimate {
    return self.containerView;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    // close any potential keyboard
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder)
                                               to:nil
                                             from:nil
                                         forEvent:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:INAPP_SDK_GLOBAL_NAME];
}

- (BOOL)dimsBackground {
    return NO;
}
@end
