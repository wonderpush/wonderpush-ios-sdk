//
//  WPHTMLInAppController.m
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2019.
//  Copyright © 2019 WonderPush. All rights reserved.
//

#import "WPHTMLInAppController.h"

@interface WPHTMLInAppController () <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIStackView *buttonStackView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *titleLabelContainerView;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *webViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *webViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (strong, nonatomic) NSArray<UIButton*> *buttons;
@end

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
    self.webView.delegate = self;
    self.titleLabel.text = self.title;
    self.titleLabelContainerView.hidden = !([self.titleLabel.text length]);
    if (self.URL) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
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

- (void) webViewDidFinishLoad:(UIWebView *)webView
{
    CGSize contentSize = webView.scrollView.contentSize;
    self.webViewWidthConstraint.constant = contentSize.width;
    self.webViewHeightConstraint.constant = contentSize.height;
    [self.view layoutIfNeeded];
    [self.activityIndicator stopAnimating];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.3 options:0 animations:^{
        self.containerView.transform = CGAffineTransformIdentity;
    } completion:nil];
}
@end
