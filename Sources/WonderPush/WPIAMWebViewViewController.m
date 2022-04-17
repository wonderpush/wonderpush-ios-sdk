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
#import "WPIAMWebViewBrige.h"

@interface WPIAMWebViewViewController () <WPIAMHitTestDelegate, WKScriptMessageHandler>

@property(nonatomic, readwrite) WPInAppMessagingWebViewDisplay *webViewMessage;
@property (weak, nonatomic) IBOutlet UIButton *backgroundCloseButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideVerticalConstraint;
@property (weak, nonatomic) IBOutlet WPIAMHitTestDelegateView *containerView;

@property(weak, nonatomic) IBOutlet UIButton *closeButton;

@property (weak, nonatomic) IBOutlet WKWebView *wkWebView;

@property(atomic) WPIAMWebViewBrige* wpiAMWebViewBrigeInstance;

@end

@implementation WPIAMWebViewViewController 

+ (WPIAMWebViewViewController *) instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                      displayMessage:(WPInAppMessagingWebViewDisplay *)webViewMessage
                                     displayDelegate:(id<WPInAppMessagingDisplayDelegate>)displayDelegate
                                         timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher {
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"WPInAppMessageDisplayStoryboard"
                                                         bundle:resourceBundle];
    
    if (storyboard == nil) {
        WPLog(@"Storyboard '"
                    "WPInAppMessageDisplayStoryboard' not found in bundle %@",
                    resourceBundle);
        return nil;
    }
    
    WPIAMWebViewViewController *webViewVC = (WPIAMWebViewViewController *)[storyboard
                                                                           instantiateViewControllerWithIdentifier:@"webview-vc"];
    
    webViewVC.displayDelegate = displayDelegate;
    webViewVC.webViewMessage = webViewMessage;
    webViewVC.timeFetcher = timeFetcher;
    webViewVC.wkWebView = webViewMessage.wkWebView;
    
    return webViewVC;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (self.wpiAMWebViewBrigeInstance == nil){
        return;
    }
    
    if([message.body isKindOfClass:[NSDictionary class]]){
        
        NSDictionary *dictionnaryParamsFromWeb = message.body;
        
        if (nil == [dictionnaryParamsFromWeb valueForKey:@"method"]){
            return;
        }
        
        if ([[dictionnaryParamsFromWeb valueForKey:@"method"]  isEqual: @"dismiss"]){
            [self.wkWebView evaluateJavaScript:@"window._wpresults['dismiss'].resolve();return promise;};" completionHandler:nil];
            [self dismissView:WPInAppMessagingDismissTypeUserTapClose];
        }
        else {
            [self.wpiAMWebViewBrigeInstance onWPIAMWebViewDidReceivedMessage:dictionnaryParamsFromWeb with:[dictionnaryParamsFromWeb valueForKey:@"method"]  in:self.wkWebView];
        }
    }
}

- (WPInAppMessagingDisplayMessage *)inAppMessage {
    return self.webViewMessage;
}

- (IBAction)closeButtonClicked:(id)sender {
    [self dismissView:WPInAppMessagingDismissTypeUserTapClose];
}

- (void)setupRecognizers {
    UITapGestureRecognizer *tapGestureRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapped:)];
    tapGestureRecognizer.delaysTouchesBegan = YES;
    tapGestureRecognizer.numberOfTapsRequired = 1;
    
    self.wkWebView.userInteractionEnabled = YES;
    [self.wkWebView addGestureRecognizer:tapGestureRecognizer];
    
    if (self.webViewMessage.closeButtonPosition == WPInAppMessagingCloseButtonPositionNone) {
        UITapGestureRecognizer *closeGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeButtonClicked:)];
        closeGestureRecognizer.delaysTouchesBegan = YES;
        closeGestureRecognizer.numberOfTapsRequired = 1;
        self.dimBackgroundView.userInteractionEnabled = YES;
        [self.dimBackgroundView addGestureRecognizer:closeGestureRecognizer];
    }
}

- (void)messageTapped:(UITapGestureRecognizer *)recognizer {
    [self followAction:self.webViewMessage.action];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor:UIColor.clearColor];
    
    self.backgroundCloseButton.backgroundColor = UIColor.clearColor;
    [self.wkWebView.configuration.userContentController addScriptMessageHandler:self name:@"WonderPushInAppSDK"];
    self.wpiAMWebViewBrigeInstance = [[WPIAMWebViewBrige alloc] init];
    self.wkWebView.opaque = false;
    self.wkWebView.backgroundColor = UIColor.clearColor;
    self.wkWebView.scrollView.backgroundColor = UIColor.clearColor;
    
    [self.wkWebView removeConstraints: [self.wkWebView constraints]];
    
    [self.containerView addSubview:self.wkWebView];
    
    NSLayoutConstraint* wkWebViewTrailingConstraint=[NSLayoutConstraint constraintWithItem:self.wkWebView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.containerView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0];
    NSLayoutConstraint* wkWebViewLeadingConstraint=[NSLayoutConstraint constraintWithItem:self.wkWebView attribute:NSLayoutAttributeLeading   relatedBy:NSLayoutRelationEqual toItem:self.containerView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0];
    NSLayoutConstraint* wkWebViewTopConstraint=[NSLayoutConstraint constraintWithItem:self.wkWebView attribute:NSLayoutAttributeTop   relatedBy:NSLayoutRelationEqual toItem:self.containerView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    NSLayoutConstraint* wkWebViewBottomConstraint=[NSLayoutConstraint constraintWithItem:self.wkWebView attribute:NSLayoutAttributeBottom   relatedBy:NSLayoutRelationEqual toItem:self.containerView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    
    [self.containerView addConstraints:@[wkWebViewTrailingConstraint, wkWebViewLeadingConstraint, wkWebViewTopConstraint, wkWebViewBottomConstraint]];
    
    [self.containerView layoutIfNeeded];
    
    if (self.webViewMessage.closeButtonPosition == WPInAppMessagingCloseButtonPositionNone){
        self.closeButton.hidden = YES;
    }
    else {
        //inside and outside are the same cause of fullscreen
        self.closeButton.hidden = NO;
    }
    
    self.containerView.pointInsideDelegate = self;
    
    [self setupRecognizers];
}

- (BOOL)pointInside:(CGPoint)point view:(UIView *)view withEvent:(UIEvent *)event {
    if (view == self.containerView) {
        if ([self.closeButton pointInside:[self.closeButton convertPoint:point fromView:view] withEvent:event]) return YES;
        return CGRectContainsPoint(self.containerView.bounds, [self.containerView convertPoint:point fromView:view]);

    }
    return NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // close any potential keyboard, which would conflict with the modal in-app messagine view
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder)
                                               to:nil
                                             from:nil
                                         forEvent:nil];
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

@end
