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

#import "WPIAMBaseRenderingViewController.h"
#import "WPCore+InAppMessagingDisplay.h"
#import "WPIAMTimeFetcher.h"
#import "WPIAMAnimationHelper.h"

@interface WPIAMBaseRenderingViewController ()
// For IAM messages, it's required to be kMinValidImpressionTime to
// be considered as a valid impression help. If the app is closed before that's reached,
// SDK may try to render the same message again in the future.
@property(nonatomic, nullable) NSTimer *minImpressionTimer;

// Tracking the start time when the current impression session start.
@property(nonatomic) double currentImpressionStartTime;

@end

static const NSTimeInterval kMinValidImpressionTime = 3.0;

@implementation WPIAMBaseRenderingViewController

- (nullable WPInAppMessagingDisplayMessage *)inAppMessage {
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.dimsBackground) {
        UIView *dimBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.dimBackgroundView = dimBackgroundView;
        self.dimBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.dimBackgroundView.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.5f];
        [self.view insertSubview:self.dimBackgroundView atIndex:0];
    }
    
    // In order to track display time for this message, we need to respond to
    // app foreground/background events since viewDidAppear/viewDidDisappear are not
    // triggered when app switches happen.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillBecomeInactive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (@available(iOS 13.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillBecomeInactive:)
                                                     name:UISceneWillDeactivateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive:)
                                                     name:UISceneDidActivateNotification
                                                   object:nil];
    }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    self.aggregateImpressionTimeInSeconds = 0;
    self.view.alpha = 0;

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self impressionStartCheckpoint];
    self.dimBackgroundView.alpha = 0;
    self.view.alpha = 1;
    [WPIAMAnimationHelper prepareEntryAnimation:self.inAppMessage.entryAnimation onView:self.viewToAnimate controller:self];
    [WPIAMAnimationHelper executeEntryAnimation:self.inAppMessage.entryAnimation onView:self.viewToAnimate controller:self completion:nil];
    [UIView animateWithDuration:0.25f animations:^{
        self.dimBackgroundView.alpha = 1;
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self impressionStopCheckpoint];
}

// Call this when the view starts to be rendered so that we can track the aggregate impression
// time for the current message
- (void)impressionStartCheckpoint {
    self.currentImpressionStartTime = [self.timeFetcher currentTimestampInSeconds];
    [self setupMinImpressionTimer];
}

// Trigger this when the view stops to be rendered so that we can track the aggregate impression
// time for the current message
- (void)impressionStopCheckpoint {
    // Pause the impression timer.
    [self.minImpressionTimer invalidate];
    
    // Track the effective impression time for this impression session.
    double effectiveImpressionTime =
    [self.timeFetcher currentTimestampInSeconds] - self.currentImpressionStartTime;
    self.aggregateImpressionTimeInSeconds += effectiveImpressionTime;
}

- (void)dealloc {
    WPLogDebug(@"[FIDBaseRenderingViewController dealloc] triggered");
    [self.minImpressionTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)appWillBecomeInactive:(NSNotification *)notification {
    [self impressionStopCheckpoint];
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    [self impressionStartCheckpoint];
}

- (void)minImpressionTimeReached {
    WPLogDebug(@"Min impression time has been reached.");
    
    if ([self.displayDelegate respondsToSelector:@selector(impressionDetectedForMessage:)]) {
        [self.displayDelegate impressionDetectedForMessage:[self inAppMessage]];
    }
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setupMinImpressionTimer {
    NSTimeInterval remaining = kMinValidImpressionTime - self.aggregateImpressionTimeInSeconds;
    WPLogDebug(@"Remaining minimal impression time is %lf", remaining);
    
    if (remaining < 0.00001) {
        return;
    }
    
    __weak id weakSelf = self;
    self.minImpressionTimer =
    [NSTimer scheduledTimerWithTimeInterval:remaining
                                     target:weakSelf
                                   selector:@selector(minImpressionTimeReached)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)dismissView:(WPInAppMessagingDismissType)dismissType {
    if (self.viewToAnimate) {
        [UIView animateWithDuration:0.25f animations:^{
            self.dimBackgroundView.alpha = 0;
        }];
        [WPIAMAnimationHelper executeExitAnimation:self.inAppMessage.exitAnimation onView:self.viewToAnimate controller:self completion:^(BOOL complete) {
            [self hideAndClean];
        }];
    } else {
        [self hideAndClean];
    }
    if (self.displayDelegate) {
        [self.displayDelegate messageDismissed:[self inAppMessage] dismissType:dismissType];
    } else {
        WPLog(@"Display delegate is nil while message is being dismissed.");
    }
    return;
}

- (void)hideAndClean {
    [self.view.window setHidden:YES];
    // This is for the purpose of releasing the potential memory associated with the image view.
    self.view.window.rootViewController = nil;
}

- (void)followAction:(WPAction *)action {
    if (self.viewToAnimate) {
        [UIView animateWithDuration:0.25f animations:^{
            self.dimBackgroundView.alpha = 0;
        }];
        [WPIAMAnimationHelper executeExitAnimation:self.inAppMessage.exitAnimation onView:self.viewToAnimate controller:self completion:^(BOOL complete) {
            [self hideAndClean];
        }];
    } else {
        [self hideAndClean];
    }
    
    if (self.displayDelegate) {
        [self.displayDelegate messageClicked:[self inAppMessage] withAction:action];
    } else {
        WPLog(@"Display delegate is nil while trying to follow action :%@.", action.targetUrl.absoluteString);
    }
    return;
}

- (UIView *)viewToAnimate {
    return self.view;
}

- (BOOL)dimsBackground {
    return YES;
}

@end
