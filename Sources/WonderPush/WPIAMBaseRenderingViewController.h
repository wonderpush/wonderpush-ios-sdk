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

#import <UIKit/UIKit.h>

#import <WonderPush/WPInAppMessagingRendering.h>
#import "WPIAMTimeFetcher.h"

@protocol WPInAppMessagingDisplayDelegate;

NS_ASSUME_NONNULL_BEGIN

@protocol WPInAppMessagingControllerDelegate <WPInAppMessagingDisplayDelegate>
- (void)trackEvent:(NSString *)type attributes:(NSDictionary * _Nullable)attributes;
@end

@interface WPIAMBaseRenderingViewController : UIViewController
@property(nonatomic, readwrite) id<WPIAMTimeFetcher> timeFetcher;
@property(nonatomic, readwrite) id<WPInAppMessagingControllerDelegate> controllerDelegate;

// These are the two methods we use to respond to app state change for the purpose of
// actual display time tracking. Subclass can override this one to have more logic for responding
// to the two events, but remember to trigger super's implementation.
- (void)appWillBecomeInactive:(NSNotification *)notification;
- (void)appDidBecomeActive:(NSNotification *)notification;

// Tracking the aggregate impression time for the rendered message. Used to determine when
// we are eaching the minimal iimpression time requirements. Exposed so that sub banner vc
// class can use it for auto dismiss tracking
@property(nonatomic) double aggregateImpressionTimeInSeconds;

// Call this when the user choose to dismiss the message
- (void)dismissView:(WPInAppMessagingDismissType)dismissType;

// Call this when end user wants to follow the action
- (void)followAction:(WPAction *)action;

// Returns the in-app message being displayed. Overridden by message type subclasses.
- (nullable WPInAppMessagingDisplayMessage *)inAppMessage;

// The view that should be animated on enter and exit. Return nil to avoid animation
- (nullable UIView *)viewToAnimate;

// Whether to add a semi-transparent background view. Defaults to YES. Override if necessary
- (BOOL)dimsBackground;

@property(nonatomic, nullable, weak) UIView *dimBackgroundView;

@end
NS_ASSUME_NONNULL_END
