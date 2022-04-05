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

@interface WPIAMWebViewViewController () <WPIAMHitTestDelegate>

@property(nonatomic, readwrite) WPInAppMessagingWebViewDisplay *webViewMessage;
@property (weak, nonatomic) IBOutlet UIButton *backgroundCloseButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideHorizontalConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideVerticalConstraint;
@property (weak, nonatomic) IBOutlet WPIAMHitTestDelegateView *containerView;

@property(weak, nonatomic) IBOutlet WKWebView *webView;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;

@end

@implementation WPIAMWebViewViewController 

+ (WPIAMWebViewViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:
                                     (WPInAppMessagingWebViewDisplay *)webViewMessage
                                displayDelegate:
                                    (id<WPInAppMessagingDisplayDelegate>)displayDelegate
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
    
    return webViewVC;
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
    
    self.webView.userInteractionEnabled = YES;
    [self.webView addGestureRecognizer:tapGestureRecognizer];
    
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

    if (self.webViewMessage.webURL) {
        NSURLRequest *requestToLoad = [NSURLRequest requestWithURL:self.webViewMessage.webURL];
        [self.webView loadRequest:requestToLoad];
    }
    
    switch (self.webViewMessage.closeButtonPosition) {
        case WPInAppMessagingCloseButtonPositionInside:
            self.closeButtonPositionInsideVerticalConstraint.priority = 999;
            self.closeButtonPositionInsideHorizontalConstraint.priority = 999;
            self.closeButton.hidden = NO;
            break;
        case WPInAppMessagingCloseButtonPositionOutside:
            self.closeButtonPositionInsideVerticalConstraint.priority = 1;
            self.closeButtonPositionInsideHorizontalConstraint.priority = 1;
            self.closeButton.hidden = NO;
            break;
        case WPInAppMessagingCloseButtonPositionNone:
            self.closeButton.hidden = YES;
            break;
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
