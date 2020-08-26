/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "WPIAMBannerViewController.h"
#import "WPCore+InAppMessagingDisplay.h"

@interface WPIAMBannerViewController ()

@property(nonatomic, readwrite) WPInAppMessagingBannerDisplay *bannerDisplayMessage;

@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewWidthConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topPaddingViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomPaddingViewHeightConstraint;
@property(nonatomic, assign) BOOL hidingForAnimation;
@property(weak, nonatomic) IBOutlet UIView *bottomPaddingView;
@property(weak, nonatomic) IBOutlet UIView *containerView;
@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property(weak, nonatomic) IBOutlet UILabel *titleLabel;
@property(weak, nonatomic) IBOutlet UILabel *bodyLabel;

@property(nonatomic, nullable) NSTimer *autoDismissTimer;
@end

// The image display area dimension in points
static const CGFloat kBannerViewImageWidth = 60;
static const CGFloat kBannerViewImageHeight = 60;

static const NSTimeInterval kBannerViewAnimationDuration = 0.3;  // in seconds

// Banner view will auto dismiss after this amount of time of showing if user does not take
// any other actions. It's in seconds.
static const NSTimeInterval kBannerAutoDimissTime = 12;

// If the window width is larger than this threshold, we cap banner view width
// by it: showing a non full-width banner when it happens.
static const CGFloat kBannerViewMaxWidth = 736;

static const CGFloat kSwipeUpThreshold = -10.0f;
static const CGFloat kSwipeDownThreshold = 10.0f;

@implementation WPIAMBannerViewController

+ (WPIAMBannerViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:(WPInAppMessagingBannerDisplay *)bannerMessage
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
    WPIAMBannerViewController *bannerVC = (WPIAMBannerViewController *)[storyboard
                                                                          instantiateViewControllerWithIdentifier:@"banner-view-vc"];
    bannerVC.displayDelegate = displayDelegate;
    bannerVC.bannerDisplayMessage = bannerMessage;
    bannerVC.timeFetcher = timeFetcher;
    
    return bannerVC;
}

- (WPInAppMessagingDisplayMessage *)inAppMessage {
    return self.bannerDisplayMessage;
}

- (void)setupRecognizers {
    UIPanGestureRecognizer *panSwipeRecognizer =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanSwipe:)];
    [self.view addGestureRecognizer:panSwipeRecognizer];
    
    UITapGestureRecognizer *tapGestureRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapped:)];
    tapGestureRecognizer.delaysTouchesBegan = YES;
    tapGestureRecognizer.numberOfTapsRequired = 1;
    
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)handlePanSwipe:(UIPanGestureRecognizer *)recognizer {
    // Detect the swipe gesture
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint vel = [recognizer velocityInView:recognizer.view];
        if (self.bannerDisplayMessage.bannerPosition == WPInAppMessagingBannerPositionTop
            &&  vel.y < kSwipeUpThreshold) {
            [self closeViewFromManualDismiss];
        }
        if (self.bannerDisplayMessage.bannerPosition == WPInAppMessagingBannerPositionBottom
            &&  vel.y > kSwipeDownThreshold) {
            [self closeViewFromManualDismiss];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self setupRecognizers];

    // When created, we are hiding it for later animation
    self.hidingForAnimation = YES;

    self.titleLabel.text = self.bannerDisplayMessage.title;
    self.bodyLabel.text = self.bannerDisplayMessage.bodyText;
    
    if (self.bannerDisplayMessage.imageData) {
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        UIImage *image = [UIImage imageWithData:self.bannerDisplayMessage.imageData.imageRawData];
        
        // Adapt image aspect ratio if needed
        if (fabs(image.size.width / image.size.height - 1) > 0.02) {
            // width and height differ by at least 2%, need to adjust image view
            // size to respect the ratio
            
            // reduce height or width of the image view to retain the ratio of the image
            if (image.size.width > image.size.height) {
                CGFloat newImageHeight = kBannerViewImageWidth * image.size.height / image.size.width;
                self.imageViewHeightConstraint.constant = newImageHeight;
            } else {
                CGFloat newImageWidth = kBannerViewImageHeight * image.size.width / image.size.height;
                self.imageViewWidthConstraint.constant = newImageWidth;
            }
        }
        self.imageView.image = image;
    } else {
        // Hide image and remove the bottom constraint between body label and image view.
        self.imageViewWidthConstraint.constant = 0;
    }
    
    // Set some rendering effects based on settings.
    self.view.backgroundColor = self.bannerDisplayMessage.displayBackgroundColor;
    self.titleLabel.textColor = self.bannerDisplayMessage.textColor;
    self.bodyLabel.textColor = self.bannerDisplayMessage.textColor;
    
    self.view.layer.masksToBounds = NO;
    self.view.layer.shadowOffset = CGSizeMake(2, 1);
    self.view.layer.shadowRadius = 2;
    self.view.layer.shadowOpacity = 0.4;
    
    [self setupAutoDismissTimer];
}

- (void)dismissViewWithAnimation:(void (^)(void))completion {
    [UIView animateWithDuration:kBannerViewAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
        [self translateOffscreen];
    }
                     completion:^(BOOL finished) {
        completion();
    }];
}

- (void)closeViewFromAutoDismiss {
    WPLogDebug(@"Auto dismiss the banner view");
    [self dismissViewWithAnimation:^(void) {
        [self dismissView:WPInAppMessagingDismissTypeAuto];
    }];
}

- (void)closeViewFromManualDismiss {
    WPLogDebug(@"Manually dismiss the banner view");
    [self.autoDismissTimer invalidate];
    [self dismissViewWithAnimation:^(void) {
        [self dismissView:WPInAppMessagingDismissTypeUserSwipe];
    }];
}

- (void)messageTapped:(UITapGestureRecognizer *)recognizer {
    [self.autoDismissTimer invalidate];
    [self dismissViewWithAnimation:^(void) {
        [self followAction:self.bannerDisplayMessage.action];
    }];
}

- (void)adjustBodyLabelViewHeight {
    // These lines make sure that we only change the height of the label view
    // to fit the content. Doing [self.bodyLabel sizeToFit] only could potentially
    // change the width as well.
    CGRect theFrame = self.bodyLabel.frame;
    [self.bodyLabel sizeToFit];
    theFrame.size.height = self.bodyLabel.frame.size.height;
    self.bodyLabel.frame = theFrame;
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    if (self.bannerDisplayMessage.bannerPosition == WPInAppMessagingBannerPositionTop) {
        self.topPaddingViewHeightConstraint.constant = self.view.safeAreaInsets.top;
        self.bottomPaddingViewHeightConstraint.constant = 0;
    } else {
        self.topPaddingViewHeightConstraint.constant = 0;
        self.bottomPaddingViewHeightConstraint.constant = self.view.safeAreaInsets.bottom;
    }
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self adjustBodyLabelViewHeight];
    if (@available(iOS 11.0, *)) {
        // Handled in viewSafeAreaInsetsDidChange
    } else {
        switch (self.bannerDisplayMessage.bannerPosition) {
            case WPInAppMessagingBannerPositionTop:
                self.topPaddingViewHeightConstraint.constant = UIApplication.sharedApplication.statusBarFrame.size.height;
                self.bottomPaddingViewHeightConstraint.constant = 0;
                break;
            case WPInAppMessagingBannerPositionBottom:
                self.topPaddingViewHeightConstraint.constant = 0;
                self.bottomPaddingViewHeightConstraint.constant = 0; // iPhone X started with iOS 11 and it's the first device with a bottom safe area inset
                break;
        }
    }
    CGFloat bannerViewHeight = CGRectGetMaxY(self.bottomPaddingView.frame);
    
    CGFloat appWindowWidth = [self.view.window bounds].size.width;
    CGFloat appWindowHeight = self.view.window.bounds.size.height;
    CGFloat bannerViewWidth = appWindowWidth;
    
    if (bannerViewWidth > kBannerViewMaxWidth) {
        bannerViewWidth = kBannerViewMaxWidth;
        self.containerView.layer.cornerRadius = 4;
    }
    
    CGRect viewRect =
    CGRectMake(
               (appWindowWidth - bannerViewWidth) / 2,
               self.bannerDisplayMessage.bannerPosition == WPInAppMessagingBannerPositionTop ? 0 : appWindowHeight - bannerViewHeight,
               bannerViewWidth,
               bannerViewHeight
               );
    self.view.frame = viewRect;
    if (self.hidingForAnimation) {
        [self translateOffscreen];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.hidingForAnimation) {
        self.hidingForAnimation = NO;
        [UIView animateWithDuration:kBannerViewAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            [self translateOnscreen];
        }
                         completion:nil];

    }
}

- (void)translateOffscreen {
    CGFloat appWindowHeight = self.view.window.bounds.size.height;
    switch (self.bannerDisplayMessage.bannerPosition) {
        case WPInAppMessagingBannerPositionBottom:
            self.view.frame = CGRectMake(0, appWindowHeight, self.view.frame.size.width, self.view.frame.size.height);
            break;
        case WPInAppMessagingBannerPositionTop:
            self.view.frame = CGRectMake(0, -self.view.frame.size.height, self.view.frame.size.width, self.view.frame.size.height);
            break;
    }
}

- (void)translateOnscreen {
    CGFloat appWindowHeight = self.view.window.bounds.size.height;
    switch (self.bannerDisplayMessage.bannerPosition) {
        case WPInAppMessagingBannerPositionBottom:
            self.view.frame = CGRectMake(0, appWindowHeight - self.view.frame.size.height, self.view.frame.size.width, self.view.frame.size.height);
            break;
        case WPInAppMessagingBannerPositionTop:
            self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
            break;
    }
}

- (void)setupAutoDismissTimer {
    NSTimeInterval remaining = kBannerAutoDimissTime - super.aggregateImpressionTimeInSeconds;
    
    WPLogDebug(@"Remaining banner auto dismiss time is %lf", remaining);
    
    // Set up the auto dismiss behavior.
    __weak id weakSelf = self;
    self.autoDismissTimer =
    [NSTimer scheduledTimerWithTimeInterval:remaining
                                     target:weakSelf
                                   selector:@selector(closeViewFromAutoDismiss)
                                   userInfo:nil
                                    repeats:NO];
}

// Handlers for app become active inactive so that we can better adjust our auto dismiss feature
- (void)appWillBecomeInactive:(NSNotification *)notification {
    [super appWillBecomeInactive:notification];
    [self.autoDismissTimer invalidate];
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    [super appDidBecomeActive:notification];
    [self setupAutoDismissTimer];
}

- (void)dealloc {
    WPLogDebug(@"-[WPIAMBannerViewController dealloc] triggered for %p", self);
    [self.autoDismissTimer invalidate];
}
@end
