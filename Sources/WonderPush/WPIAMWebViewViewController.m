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

@interface WPIAMWebViewViewController () <WPIAMHitTestDelegate, WKNavigationDelegate>

@property(nonatomic, readwrite) WPInAppMessagingWebViewDisplay *webViewMessage;
@property (weak, nonatomic) IBOutlet UIButton *backgroundCloseButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideHorizontalConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideVerticalConstraint;
@property (weak, nonatomic) IBOutlet WPIAMHitTestDelegateView *containerView;

@property(weak, nonatomic) IBOutlet WKWebView *webView;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;

@property(atomic) Boolean webViewUrlLoadingCallbackHasBeenDone;
@property(atomic) void (^successWebViewUrlLoadingBlock)(void);
@property(atomic) void (^errorWebViewUrlLoadingBlock)(NSError *);

@property(retain, atomic) dispatch_semaphore_t webViewCallbackTreatmentSemaphore;

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
    
    return webViewVC;
}

- (void) preLoadWebViewUrlWithSuccessCompletionHander: (void (^)(void)) successBlock
                            withErrorCompletionHander: (void (^)(NSError *)) errorBlock{
    
    self.webViewUrlLoadingCallbackHasBeenDone = false;
    self.webViewCallbackTreatmentSemaphore = dispatch_semaphore_create(1);
    self.successWebViewUrlLoadingBlock = successBlock;
    self.errorWebViewUrlLoadingBlock = errorBlock;
    
    //Loads the view controller’s view if it has not yet been loaded.
    [self loadViewIfNeeded];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    dispatch_semaphore_wait(self.webViewCallbackTreatmentSemaphore, DISPATCH_TIME_FOREVER);
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.errorWebViewUrlLoadingBlock(error);
        self.webViewUrlLoadingCallbackHasBeenDone = true;
    }
    dispatch_semaphore_signal(self.webViewCallbackTreatmentSemaphore);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    dispatch_semaphore_wait(self.webViewCallbackTreatmentSemaphore, DISPATCH_TIME_FOREVER);
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.errorWebViewUrlLoadingBlock(error);
        self.webViewUrlLoadingCallbackHasBeenDone = true;
    }
    dispatch_semaphore_signal(self.webViewCallbackTreatmentSemaphore);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {

    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {

        NSHTTPURLResponse * response = (NSHTTPURLResponse *)navigationResponse.response;
        if (response.statusCode >= 400) {

            decisionHandler(WKNavigationResponsePolicyCancel);
            return;
        }

    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    dispatch_semaphore_wait(self.webViewCallbackTreatmentSemaphore, DISPATCH_TIME_FOREVER);
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.successWebViewUrlLoadingBlock();
        self.webViewUrlLoadingCallbackHasBeenDone = true;
    }
    dispatch_semaphore_signal(self.webViewCallbackTreatmentSemaphore);
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
        self.webView.navigationDelegate = self;
        NSURLRequest *requestToLoad = [NSURLRequest requestWithURL:self.webViewMessage.webURL];
        [self.webView loadRequest:requestToLoad];
        
        // Delay execution of my block for 2 seconds.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            dispatch_semaphore_wait(self.webViewCallbackTreatmentSemaphore, DISPATCH_TIME_FOREVER);
            if (false == self.webViewUrlLoadingCallbackHasBeenDone){
                self.errorWebViewUrlLoadingBlock([NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                                     code:IAMDisplayRenderErrorTypeWebUrlFailedToLoad
                                                                 userInfo:@{}]);
                self.webViewUrlLoadingCallbackHasBeenDone = true;
            }
            dispatch_semaphore_signal(self.webViewCallbackTreatmentSemaphore);
        });
    }
    else {
        self.errorWebViewUrlLoadingBlock([NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                             code:IAMDisplayRenderErrorTypeUnspecifiedError
                                         userInfo:@{}]);
        self.webViewUrlLoadingCallbackHasBeenDone = true;
        return;
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
