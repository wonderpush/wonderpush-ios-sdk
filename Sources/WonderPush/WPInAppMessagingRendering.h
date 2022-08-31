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
#import "WPAction.h"

NS_ASSUME_NONNULL_BEGIN

/// The type and UI style of an in-app message.
typedef NS_ENUM(NSInteger, WPInAppMessagingDisplayMessageType) {
    /// Modal style.
    WPInAppMessagingDisplayMessageTypeModal,
    /// Banner style.
    WPInAppMessagingDisplayMessageTypeBanner,
    /// Image-only style.
    WPInAppMessagingDisplayMessageTypeImageOnly,
    /// Card style.
    WPInAppMessagingDisplayMessageTypeCard
};

/// Represents how an in-app message should be triggered to appear.
typedef NS_ENUM(NSInteger, WPInAppMessagingDisplayTriggerType) {
    /// Triggered on app foreground.
    WPInAppMessagingDisplayTriggerTypeOnAppForeground,
    /// Triggered from an analytics event being fired.
    WPInAppMessagingDisplayTriggerTypeOnWonderPushEvent
};

/// Where to place the close button
typedef NS_ENUM(NSInteger, WPInAppMessagingCloseButtonPosition) {
    /// Centered on the upper right corner
    WPInAppMessagingCloseButtonPositionOutside,
    /// Inside the upper right corner
    WPInAppMessagingCloseButtonPositionInside,
    /// Hidden
    WPInAppMessagingCloseButtonPositionNone,
};

/// Where to place the banner
typedef NS_ENUM(NSInteger, WPInAppMessagingBannerPosition) {
    /// At the top of the screen
    WPInAppMessagingBannerPositionTop,
    /// At the bottom of the screen
    WPInAppMessagingBannerPositionBottom,
};

/// Entry animations
typedef NS_ENUM(NSInteger, WPInAppMessagingEntryAnimation) {
    /// Fade in
    WPInAppMessagingEntryAnimationFadeIn,
    /// Slide into view from the right side of the screen
    WPInAppMessagingEntryAnimationSlideInFromRight,
    /// Slide into view from the left side of the screen
    WPInAppMessagingEntryAnimationSlideInFromLeft,
    /// Slide into view from the top of the screen
    WPInAppMessagingEntryAnimationSlideInFromTop,
    /// Slide into view from the bottom of the screen
    WPInAppMessagingEntryAnimationSlideInFromBottom,
};

/// Exit animations
typedef NS_ENUM(NSInteger, WPInAppMessagingExitAnimation) {
    /// Fade out
    WPInAppMessagingExitAnimationFadeOut,
    /// Slide out of the view from the right side of the screen
    WPInAppMessagingExitAnimationSlideOutRight,
    /// Slide out of the view from the left side of the screen
    WPInAppMessagingExitAnimationSlideOutLeft,
    /// Slide out of the view from the top of the screen
    WPInAppMessagingExitAnimationSlideOutUp,
    /// Slide out of the view from the bottom of the screen
    WPInAppMessagingExitAnimationSlideOutDown,
};

/** Contains the display information for an action button.
 */
NS_SWIFT_NAME(InAppMessagingActionButton)
@interface WPInAppMessagingActionButton : NSObject

/**
 * Gets the text string for the button
 */
@property(nonatomic, nonnull, copy, readonly) NSString *buttonText;

/**
 * Gets the button's text color.
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *buttonTextColor;

/**
 * Gets the button's background color
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *buttonBackgroundColor;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/** Contain display data for an image for a IAM message.
 */
NS_SWIFT_NAME(InAppMessagingImageData)
@interface WPInAppMessagingImageData : NSObject

/**
 * Gets the image URL from image data.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *imageURL;

/**
 * Gets the downloaded image data. It can be null if headless component fails to load it.
 */
@property(nonatomic, readonly, nullable) NSData *imageRawData;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/**
 * Base class representing a IAM message to be displayed. Don't create instance
 * of this class directly. Instantiate one of its subclasses instead.
 */
NS_SWIFT_NAME(InAppMessagingDisplayMessage)
@interface WPInAppMessagingDisplayMessage : NSObject

/**
 * The type and UI style of this message.
 */
@property(nonatomic, readonly) WPInAppMessagingDisplayMessageType type;

/**
 * How this message should be triggered.
 */
@property(nonatomic, readonly) WPInAppMessagingDisplayTriggerType triggerType;

/**
 * Custom data.
 */
@property(nonatomic, readonly) NSDictionary *payload;

/**
 * Entry animation
 */
@property(nonatomic, readonly) WPInAppMessagingEntryAnimation entryAnimation;

/**
 * Exit animation
 */
@property(nonatomic, readonly) WPInAppMessagingExitAnimation exitAnimation;


/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(InAppMessagingCardDisplay)
@interface WPInAppMessagingCardDisplay : WPInAppMessagingDisplayMessage

/**
 * Gets the title text for a card IAM message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *title;

/**
 * Gets the body text for a card IAM message.
 */
@property(nonatomic, nullable, copy, readonly) NSString *body;

/**
 * Gets the color for text in card IAM message. It applies to both title and body text.
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *textColor;

/**
 * Image data for the supplied portrait image for a card IAM messasge.
 */
@property(nonatomic, nonnull, copy, readonly) WPInAppMessagingImageData *portraitImageData;

/**
 * Image data for the supplied landscape image for a card IAM message.
 */
@property(nonatomic, nullable, copy, readonly) WPInAppMessagingImageData *landscapeImageData;

/**
 * The background color for a card IAM message.
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *displayBackgroundColor;

/**
 * Metadata for a card IAM message's primary action button.
 */
@property(nonatomic, nonnull, readonly) WPInAppMessagingActionButton *primaryActionButton;

/**
 * The action URL for a card IAM message's primary action button.
 */
@property(nonatomic, nullable, readonly) WPAction *primaryAction;

/**
 * Metadata for a card IAM message's secondary action button.
 */
@property(nonatomic, nullable, readonly) WPInAppMessagingActionButton *secondaryActionButton;

/**
 * The action URL for a card IAM message's secondary action button.
 */
@property(nonatomic, nullable, readonly) WPAction *secondaryAction;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/** Class for defining a modal message for display.
 */
NS_SWIFT_NAME(InAppMessagingModalDisplay)
@interface WPInAppMessagingModalDisplay : WPInAppMessagingDisplayMessage

/**
 * Gets the title for a modal IAM message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *title;

/**
 * Gets the image data for a modal IAM message.
 */
@property(nonatomic, nullable, copy, readonly) WPInAppMessagingImageData *imageData;

/**
 * Gets the body text for a modal IAM message.
 */
@property(nonatomic, nullable, copy, readonly) NSString *bodyText;

/**
 * Gets the action button metadata for a modal IAM message.
 */
@property(nonatomic, nullable, readonly) WPInAppMessagingActionButton *actionButton;

/**
 * Gets the action URL for a modal IAM message.
 */
@property(nonatomic, nullable, readonly) WPAction *action;

/**
 * Gets the background color for a modal IAM message.
 */
@property(nonatomic, copy, nonnull) UIColor *displayBackgroundColor;

/**
 * Gets the color for text in modal IAM message. It would apply to both title and body text.
 */
@property(nonatomic, copy, nonnull) UIColor *textColor;

/**
 * Where to put the close button
 */
@property(nonatomic, readonly) WPInAppMessagingCloseButtonPosition closeButtonPosition;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/** Class for defining a banner message for display.
 */
NS_SWIFT_NAME(InAppMessagingBannerDisplay)
@interface WPInAppMessagingBannerDisplay : WPInAppMessagingDisplayMessage

/**
 * Gets the title of a banner message.
 */
@property(nonatomic, nonnull, copy, readonly) NSString *title;

/**
 * Gets the image data for a banner message.
 */
@property(nonatomic, nullable, copy, readonly) WPInAppMessagingImageData *imageData;

/**
 * Gets the body text for a banner message.
 */
@property(nonatomic, nullable, copy, readonly) NSString *bodyText;

/**
 * Gets banner's background color
 */
@property(nonatomic, copy, nonnull, readonly) UIColor *displayBackgroundColor;

/**
 * Gets the color for text in banner IAM message. It would apply to both title and body text.
 */
@property(nonatomic, copy, nonnull) UIColor *textColor;

/**
 * Where to place the banner.
 */
@property(nonatomic, assign) WPInAppMessagingBannerPosition bannerPosition;

/**
 * Gets the action URL for a banner IAM message.
 */
@property(nonatomic, nullable, readonly) WPAction *action;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/** Class for defining a image-only message for display.
 */
NS_SWIFT_NAME(InAppMessagingImageOnlyDisplay)
@interface WPInAppMessagingImageOnlyDisplay : WPInAppMessagingDisplayMessage

/**
 * Gets the image for this message
 */
@property(nonatomic, nonnull, copy, readonly) WPInAppMessagingImageData *imageData;

/**
 * Gets the action URL for an image-only IAM message.
 */
@property(nonatomic, nullable, readonly) WPAction *action;

/**
 * Where to put the close button
 */
@property(nonatomic, readonly) WPInAppMessagingCloseButtonPosition closeButtonPosition;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/** Class for defining a webview message for display.
 */
NS_SWIFT_NAME(InAppMessagingWebViewDisplay)
@interface WPInAppMessagingWebViewDisplay : WPInAppMessagingDisplayMessage

/**
 * Gets the action URL for an webView IAM message.
 */
@property(nonatomic, nullable, readonly) WPAction *action;

/**
 * Where to put the close button
 */
@property(nonatomic, readonly) WPInAppMessagingCloseButtonPosition closeButtonPosition;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

/// The way that an in-app message was dismissed.
typedef NS_ENUM(NSInteger, WPInAppMessagingDismissType) {
  /// Message was swiped away (only valid for banner messages).
  WPInAppMessagingDismissTypeUserSwipe,
  /// The user tapped a button to close this message.
  WPInAppMessagingDismissTypeUserTapClose,
  /// The message was automatically dismissed (only valid for banner messages).
  WPInAppMessagingDismissTypeAuto,
  /// Dismiss method unknown.
  WPInAppMessagingDismissUnspecified,
};

/// Error code for an in-app message that failed to display.
typedef NS_ENUM(NSInteger, IAMDisplayRenderErrorType) {
  /// The image data for this in-app message is invalid.
  IAMDisplayRenderErrorTypeImageDataInvalid,
  /// The url data can't be loaded
  IAMDisplayRenderErrorTypeWebUrlFailedToLoad,
  /// The UIApplication is not active when time comes to render the message
  IAMDisplayRenderErrorTypeApplicationNotActiveError,
  /// Timeout error.
  IAMDisplayRenderErrorTypeTimeoutError,
  /// HTTP error.
  IAMDisplayRenderErrorTypeHTTPError,
  /// Authentication required
  IAMDisplayRenderErrorTypeAuthenticationRequiredError,
  /// Navigation became download
  IAMDisplayRenderErrorTypeNavigationBecameDownloadError,
  /// Unknown method.
  IAMDisplayRenderErrorTypeUnknownMethodError,
  /// Unexpected error.
  IAMDisplayRenderErrorTypeUnspecifiedError,
};

/**
 * A protocol defining those callbacks to be triggered by the message display component
 * under appropriate conditions.
 */
NS_SWIFT_NAME(InAppMessagingDisplayDelegate)
@protocol WPInAppMessagingDisplayDelegate <NSObject>

@optional

/**
 * Called when a labelled button is clicked without an Action. The in-app is still visible until `messageDismissed:dismissType:` or `messageClicked:withAction:` is called.
 * @param inAppMessage the message that was clicked.
 * @param buttonLabel specifies the button label
 */
- (void)trackClickWithMessage:(WPInAppMessagingDisplayMessage *)inAppMessage
       buttonLabel:(NSString *)buttonLabel;

/**
 * Called when the message is dismissed. Should be called from main thread.
 * @param inAppMessage the message that was dismissed.
 * @param dismissType specifies how the message is closed.
 */
- (void)messageDismissed:(WPInAppMessagingDisplayMessage *)inAppMessage
             dismissType:(WPInAppMessagingDismissType)dismissType;

/**
 * Called when the message's action button is followed by the user.
 * @param inAppMessage the message that was clicked.
 * @param action contains the text and URL for the action that was clicked.
 */
- (void)messageClicked:(WPInAppMessagingDisplayMessage *)inAppMessage
            withAction:(WPAction *)action;

/**
 * Use this to mark a message as having gone through enough impression so that
 * headless component can make appropriate impression tracking for it.
 *
 * Calling this is optional.
 *
 * When messageDismissedWithType: or messageClicked is
 * triggered, the message would be marked as having a valid impression implicitly.
 * Use impressionDetected if the UI implementation would like to mark valid
 * impression in additional cases. One example is that the message is displayed for
 * N seconds and then the app is killed by the user. Neither
 * onMessageDismissedWithType or onMessageClicked would be triggered
 * in this case. But if the app regards this as a valid impression and does not
 * want the user to see the same message again, call impressionDetected to mark
 * a valid impression.
 * @param inAppMessage the message for which an impression was detected.
 */
- (void)impressionDetectedForMessage:(WPInAppMessagingDisplayMessage *)inAppMessage;

/**
 * Called when the display component could not render the message due to various reason.
 * It's essential for display component to call this when error does arise. On seeing
 * this, the headless component of IAM would assume that a prior attempt to render a
 * message has finished and therefore it's ready to render a new one when conditions are
 * met. Missing this callback in failed rendering attempt would make headless
 * component think a IAM message is still being rendered and therefore suppress any
 * future message rendering.
 * @param inAppMessage the message that encountered a display error.
 */
- (void)displayErrorForMessage:(WPInAppMessagingDisplayMessage *)inAppMessage
                         error:(NSError *)error;
@end

/**
 * The protocol that a IAM display component must implement.
 */
NS_SWIFT_NAME(InAppMessagingDisplay)
@protocol WPInAppMessagingDisplay

/**
 * Method for rendering a specified message on client side. It's called from main thread.
 * @param messageForDisplay the message object. It would be of one of the three message
 *   types at runtime.
 * @param displayDelegate the callback object you *must* use to report impressions, clicks and dismisses
 * @return NO when the message should be handled by the default, buit-in WPInAppMessagingDisplay instance. This instance will take care of reporting impressions and clicks to the display delegate. YES if the message was handled.
 */
- (BOOL)displayMessage:(WPInAppMessagingDisplayMessage *)messageForDisplay
       displayDelegate:(id<WPInAppMessagingDisplayDelegate>)displayDelegate;
@end
NS_ASSUME_NONNULL_END
