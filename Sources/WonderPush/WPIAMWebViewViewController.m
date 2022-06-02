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

@interface WPIAMWebViewViewController ()

@property(nonatomic, readwrite) WPInAppMessagingWebViewDisplay *webViewMessage;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet WKWebView *webView;
@end

@implementation WPIAMWebViewViewController 

+ (WPIAMWebViewViewController *) instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                      displayMessage:(WPInAppMessagingWebViewDisplay *)webViewMessage
                                     displayDelegate:(id<WPInAppMessagingDisplayDelegate>)displayDelegate
                                         timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher {
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"WPInAppMessageDisplayStoryboard"
                                                         bundle:resourceBundle];
    
    if (storyboard == nil) {
        WPLog(@"Storyboard 'WPInAppMessageDisplayStoryboard' not found in bundle %@", resourceBundle);
        return nil;
    }
    
    WPIAMWebViewViewController *webViewVC = (WPIAMWebViewViewController *)[storyboard
                                                                           instantiateViewControllerWithIdentifier:@"webview-vc"];
    
    webViewVC.displayDelegate = displayDelegate;
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
    
    [self.view setBackgroundColor:UIColor.clearColor];
    
    self.webView.opaque = false;
    self.webView.backgroundColor = UIColor.clearColor;
    self.webView.scrollView.backgroundColor = UIColor.clearColor;
    if ([self.webView isKindOfClass:WPIAMWebView.class]) {
        __weak WPIAMWebView *webView = (WPIAMWebView *)self.webView;
        __weak WPIAMWebViewViewController *weakSelf = self;
        webView.onDismiss = ^(WPInAppMessagingDismissType type) {
            [weakSelf dismissView:type];
            webView.onDismiss = nil;
        };
    }
    
    [self.webView removeConstraints: [self.webView constraints]];
    
    [self.view insertSubview:self.webView belowSubview:self.closeButton];
    
    NSLayoutConstraint* webViewTrailingConstraint=[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0];
    NSLayoutConstraint* webViewLeadingConstraint=[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeLeading   relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0];
    NSLayoutConstraint* webViewTopConstraint=[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTop   relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    NSLayoutConstraint* webViewBottomConstraint=[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeBottom   relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    NSLayoutConstraint* closeButtonTrailingConstraint=[NSLayoutConstraint constraintWithItem:self.closeButton attribute:NSLayoutAttributeTrailing   relatedBy:NSLayoutRelationEqual toItem:self.webView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:-8];

    [self.view addConstraints:@[webViewTrailingConstraint, webViewLeadingConstraint, webViewTopConstraint, webViewBottomConstraint, closeButtonTrailingConstraint]];
    
    [self.view layoutIfNeeded];
    
    if (self.webViewMessage.closeButtonPosition == WPInAppMessagingCloseButtonPositionNone){
        self.closeButton.hidden = YES;
    } else {
        //inside and outside are the same cause of fullscreen
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
    return self.webView;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    // close any potential keyboard, which would conflict with the modal in-app messagine view
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder)
                                               to:nil
                                             from:nil
                                         forEvent:nil];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"WonderPushInAppSDK"];
}

@end
