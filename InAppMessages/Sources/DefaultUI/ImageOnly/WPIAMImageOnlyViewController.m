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

@interface WPIAMImageOnlyViewController ()

@property(nonatomic, readwrite) WPInAppMessagingImageOnlyDisplay *imageOnlyMessage;

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
}

- (void)messageTapped:(UITapGestureRecognizer *)recognizer {
    [self followAction:self.imageOnlyMessage.action];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor.grayColor colorWithAlphaComponent:0.5]];
    
    if (self.imageOnlyMessage.imageData) {
        UIImage *image = [UIImage imageWithData:self.imageOnlyMessage.imageData.imageRawData];
        self.imageOriginalSize = image.size;
        [self.imageView setImage:image];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    [self setupRecognizers];
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
    CGFloat maxImageViewWidth = self.view.window.frame.size.width - minimalMargine * 2;
    CGFloat maxImageViewHeight = self.view.window.frame.size.height - minimalMargine * 2;
    
    // Factor in space for the top notch on iPhone X*.
#if defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        maxImageViewHeight -= self.view.safeAreaInsets.top;
    }
#endif  // defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    
    CGFloat adjustedImageViewHeight = self.imageOriginalSize.height;
    CGFloat adjustedImageViewWidth = self.imageOriginalSize.width;
    
    if (adjustedImageViewWidth > maxImageViewWidth || adjustedImageViewHeight > maxImageViewHeight) {
        if (maxImageViewHeight / maxImageViewWidth >
            self.imageOriginalSize.height / self.imageOriginalSize.width) {
            // the image is relatively too wide compared against displayable area
            adjustedImageViewWidth = maxImageViewWidth;
            adjustedImageViewHeight =
            adjustedImageViewWidth * self.imageOriginalSize.height / self.imageOriginalSize.width;
            
            WPLogDebug(@"Use max available image display width as %lf", adjustedImageViewWidth);
        } else {
            // the image is relatively too narrow compared against displayable area
            adjustedImageViewHeight = maxImageViewHeight;
            adjustedImageViewWidth =
            adjustedImageViewHeight * self.imageOriginalSize.width / self.imageOriginalSize.height;
            WPLogDebug(@"Use max avilable image display height as %lf", adjustedImageViewHeight);
        }
    } else {
        // image can be rendered fully at its original size
        WPLogDebug(@"Image can be fully displayed in image only mode");
    }
    
    CGRect rect = CGRectMake(0, 0, adjustedImageViewWidth, adjustedImageViewHeight);
    self.imageView.frame = rect;
    self.imageView.center = self.view.center;
    
    CGFloat closeButtonCenterX = CGRectGetMaxX(self.imageView.frame);
    CGFloat closeButtonCenterY = CGRectGetMinY(self.imageView.frame);
    self.closeButton.center = CGPointMake(closeButtonCenterX, closeButtonCenterY);
    
    [self.view bringSubviewToFront:self.closeButton];
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
@end
