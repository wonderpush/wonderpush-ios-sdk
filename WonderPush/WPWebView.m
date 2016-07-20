//
//  WPWebView.m
//  WonderPush
//
//  Created by Olivier Favre on 13/06/16.
//  Copyright © 2016 WonderPush. All rights reserved.
//

#import "WPWebView.h"

#import <Foundation/Foundation.h>

@interface WPWebView ()

@property (nonatomic) BOOL contentLoaded;
@property (weak, nonatomic) UIView *alertContentView;
@property (weak, nonatomic) UIScrollView *alertScrollView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@end

@implementation WPWebView

- (instancetype)init
{
    self = [super init];

    self.delegate = self;
    _contentLoaded = NO;
    self.scalesPageToFit = NO; // does not work prevent zooming without overriding [viewForZoomingInScrollView:] too
    self.scrollView.bounces = NO;
    self.autoresizingMask = 0;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_spinner startAnimating];
    [self addSubview:_spinner];
    [self bringSubviewToFront:_spinner];

    return self;
}

- (void)applyLayoutWithAlertComponentViews:(NSDictionary *)views
{
    _alertContentView = PKAlertGetViewInViews(PKAlertContentViewKey, views);
    _alertScrollView = (UIScrollView *) PKAlertGetViewInViews(PKAlertScrollViewKey, views);
    _alertScrollView.bounces = NO;
}

- (CGSize)intrinsicContentSize
{
    return [self getSize];
}

- (CGSize)visibleSizeInAlertView
{
    // Asynchronously change the view height to match the alert scrollview so both horizontal and vertical scrolling are handled by the webview
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.frame.size.height != _alertScrollView.frame.size.height) {
            CGRect frame = self.frame;
            frame.size.height = _alertScrollView.frame.size.height;
            [self setFrame:frame];
        }
    });
    return [self getSize];
}

- (CGSize)getSize
{
    CGSize rtn;
    if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1) {
        // The resize after webViewDidFinishLoad does not work on iPhone 7 somehow
        rtn = CGSizeMake(self.frame.size.width, 276); // 276 is the max height with 3 buttons on an iPhone 4
    } else if (!_contentLoaded) {
        rtn = _spinner.frame.size;
        rtn.width  += 30;
        rtn.height += 30;
    } else {
        rtn = self.scrollView.subviews.firstObject.frame.size;
    }
    return rtn;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    _contentLoaded = YES;
    [_spinner removeFromSuperview];
    [_spinner stopAnimating];
    [self invalidateIntrinsicContentSize];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    // Disables zooming
    return nil;
}

@end
