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

#import "WPIAMImageOnlyViewController.h"
#import "WPCore+InAppMessagingDisplay.h"
#import "WPIAMHitTestDelegateView.h"

@interface WPIAMImageOnlyViewController () <WPIAMHitTestDelegate>

@property(nonatomic, readwrite) WPInAppMessagingImageOnlyDisplay *imageOnlyMessage;
@property (weak, nonatomic) IBOutlet UIButton *backgroundCloseButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideHorizontalConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *closeButtonPositionInsideVerticalConstraint;
@property (weak, nonatomic) IBOutlet WPIAMHitTestDelegateView *containerView;

@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;
@property(nonatomic, assign) CGSize imageOriginalSize;
@end

@implementation WPIAMImageOnlyViewController

+ (WPIAMImageOnlyViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:
                                     (WPInAppMessagingImageOnlyDisplay *)imageOnlyMessage
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
    WPIAMImageOnlyViewController *imageOnlyVC = (WPIAMImageOnlyViewController *)[storyboard
                                                                                   instantiateViewControllerWithIdentifier:@"image-only-vc"];
    imageOnlyVC.displayDelegate = displayDelegate;
    imageOnlyVC.imageOnlyMessage = imageOnlyMessage;
    imageOnlyVC.timeFetcher = timeFetcher;
    
    return imageOnlyVC;
}

- (WPInAppMessagingDisplayMessage *)inAppMessage {
    return self.imageOnlyMessage;
}

- (IBAction)closeButtonClicked:(id)sender {
    [self dismissView:WPInAppMessagingDismissTypeUserTapClose];
}

- (void)setupRecognizers {
    UITapGestureRecognizer *tapGestureRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapped:)];
    tapGestureRecognizer.delaysTouchesBegan = YES;
    tapGestureRecognizer.numberOfTapsRequired = 1;
    
    self.imageView.userInteractionEnabled = YES;
    [self.imageView addGestureRecognizer:tapGestureRecognizer];
    
    if (self.imageOnlyMessage.closeButtonPosition == WPInAppMessagingCloseButtonPositionNone) {
        UITapGestureRecognizer *closeGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeButtonClicked:)];
        closeGestureRecognizer.delaysTouchesBegan = YES;
        closeGestureRecognizer.numberOfTapsRequired = 1;
        self.dimBackgroundView.userInteractionEnabled = YES;
        [self.dimBackgroundView addGestureRecognizer:closeGestureRecognizer];
    }
}

- (void)messageTapped:(UITapGestureRecognizer *)recognizer {
    [self followAction:self.imageOnlyMessage.action];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:UIColor.clearColor];
    self.backgroundCloseButton.backgroundColor = UIColor.clearColor;

    if (self.imageOnlyMessage.imageData) {
        UIImage *image = [UIImage imageWithData:self.imageOnlyMessage.imageData.imageRawData];
        self.imageOriginalSize = image.size;
        [self.imageView setImage:image];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    switch (self.imageOnlyMessage.closeButtonPosition) {
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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (!self.imageOnlyMessage.imageData) {
        return;
    }
    
    // do the calculation in viewDidLayoutSubViews since self.view.window.frame is only
    // reliable at this time
    
    // Calculate the size of the image view under the constraints:
    // 1 Retain the image ratio
    // 2 Have at least 30 point of margines around four sides of the image view
    
    CGFloat minimalMargine = 30;  // 30 points
    CGFloat maxContainerViewWidth = self.view.window.frame.size.width - minimalMargine * 2;
    CGFloat maxContainerViewHeight = self.view.window.frame.size.height - minimalMargine * 2;
    
    // Factor in space for the top notch on iPhone X*.
#if defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        maxContainerViewHeight -= self.view.safeAreaInsets.top;
    }
#endif  // defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    
    CGFloat adjustedContainerViewHeight = self.imageOriginalSize.height;
    CGFloat adjustedContainerViewWidth = self.imageOriginalSize.width;
    
    if (adjustedContainerViewWidth > maxContainerViewWidth || adjustedContainerViewHeight > maxContainerViewHeight) {
        if (maxContainerViewHeight / maxContainerViewWidth >
            self.imageOriginalSize.height / self.imageOriginalSize.width) {
            // the image is relatively too wide compared against displayable area
            adjustedContainerViewWidth = maxContainerViewWidth;
            adjustedContainerViewHeight =
            adjustedContainerViewWidth * self.imageOriginalSize.height / self.imageOriginalSize.width;
            
            WPLogDebug(@"Use max available image display width as %lf", adjustedContainerViewWidth);
        } else {
            // the image is relatively too narrow compared against displayable area
            adjustedContainerViewHeight = maxContainerViewHeight;
            adjustedContainerViewWidth =
            adjustedContainerViewHeight * self.imageOriginalSize.width / self.imageOriginalSize.height;
            WPLogDebug(@"Use max avilable image display height as %lf", adjustedContainerViewHeight);
        }
    } else {
        // image can be rendered fully at its original size
        WPLogDebug(@"Image can be fully displayed in image only mode");
    }
    
    CGRect rect = CGRectMake(0, 0, adjustedContainerViewWidth, adjustedContainerViewHeight);
    self.containerView.frame = rect;
    self.containerView.center = self.view.center;
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
