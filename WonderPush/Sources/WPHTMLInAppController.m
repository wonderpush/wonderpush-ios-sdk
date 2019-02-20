//
//  WPHTMLInAppController.m
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2019.
//  Copyright © 2019 WonderPush. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "WPHTMLInAppController.h"
#import "WPLog.h"

@interface WPHTMLInAppController () <WKNavigationDelegate>
@property (weak, nonatomic) IBOutlet UIStackView *buttonStackView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *titleLabelContainerView;
@property (weak, nonatomic) IBOutlet UIStackView *mainStackView;
@property (strong, nonatomic) IBOutlet WKWebView *webView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *webViewWidthConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *webViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (strong, nonatomic) NSArray<UIButton*> *buttons;
@property (assign, nonatomic) BOOL loaded;
@end

static NSTimeInterval timeout = 60;
@implementation WPHTMLInAppAction
+ (instancetype) actionWithTitle:(NSString *)title block:(void (^)(WPHTMLInAppAction *))block
{
    WPHTMLInAppAction *action = [WPHTMLInAppAction new];
    action.title = title;
    action.block = block;
    return action;
}
@end

@implementation WPHTMLInAppController

- (void)viewDidLoad {
    [super viewDidLoad];
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.allowsInlineMediaPlayback = YES;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webViewWidthConstraint = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0 constant:1000];
    self.webViewWidthConstraint.priority = 500;
    self.webViewHeightConstraint = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0 constant:1000];
    self.webViewHeightConstraint.priority = 500;
    [self.webView addConstraints:@[self.webViewWidthConstraint, self.webViewHeightConstraint]];
    [self.mainStackView addArrangedSubview:self.webView];
    
    self.webView.navigationDelegate = self;
    self.titleLabel.text = self.title;
    self.titleLabelContainerView.hidden = !([self.titleLabel.text length]);
    if (self.URL) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL];
        request.timeoutInterval = timeout;
        [self.webView loadRequest:request];
    } else if (self.HTMLString) {
        [self.webView loadHTMLString:self.HTMLString baseURL:self.baseURL];
    }
    for (NSInteger i = 0; i < self.actions.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        WPHTMLInAppAction *action = self.actions[i];
        button.tag = i;
        [button setTitle:action.title forState:UIControlStateNormal];
        [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [button setBackgroundColor:[UIColor whiteColor]];
        [self.buttonStackView addArrangedSubview:button];
    }
    [self.activityIndicator startAnimating];
    self.containerView.transform = CGAffineTransformMakeScale(0, 0);
    
    // Timeout
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.loaded) {
            WPLog(@"Timeout loading in-app");
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

- (void)dealloc
{
    [self.webView.scrollView removeObserver:self forKeyPath:@"contentSize" context:nil];
}

- (void) buttonClicked:(id)sender
{
    UIView *senderView = sender;
    WPHTMLInAppAction *action = self.actions[senderView.tag];
    action.block(action);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == self.webView.scrollView && [keyPath isEqual:@"contentSize"]) {
        CGSize contentSize = self.webView.scrollView.contentSize;
        self.webViewWidthConstraint.constant = contentSize.width;
        self.webViewHeightConstraint.constant = contentSize.height;
        [self.view layoutIfNeeded];
        [self.activityIndicator stopAnimating];
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.3 options:0 animations:^{
            self.containerView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if (!self.loaded) {
        self.loaded = YES;
        [self.webView.scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
    }
}
- (void) webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    self.loaded = YES;
    WPLog(@"Could not load in-app website: %@", error);
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
