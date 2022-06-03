/*
 * Copyright 2019 Google
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

#import <WonderPush/WPInAppMessagingRendering.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPInAppMessagingCardDisplay (Private)

- (void)setBody:(NSString *_Nullable)body;
- (void)setLandscapeImageData:(WPInAppMessagingImageData *_Nullable)landscapeImageData;
- (void)setSecondaryActionButton:(WPInAppMessagingActionButton *_Nullable)secondaryActionButton;
- (void)setSecondaryAction:(WPAction *_Nullable)secondaryAction;

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          titleText:(NSString *)title
                          textColor:(UIColor *)textColor
                  portraitImageData:(WPInAppMessagingImageData *)portraitImageData
                    backgroundColor:(UIColor *)backgroundColor
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                primaryActionButton:(WPInAppMessagingActionButton *)primaryActionButton
                      primaryAction:(nullable WPAction *)primaryAction;
@end

@interface WPInAppMessagingActionButton (Private)

- (instancetype)initWithButtonText:(NSString *)btnText
                   buttonTextColor:(UIColor *)textColor
                   backgroundColor:(UIColor *)bkgColor;

@end

@interface WPInAppMessagingImageData (Private)

- (instancetype)initWithImageURL:(NSString *)imageURL imageData:(NSData *)imageData;

@end

@interface WPInAppMessagingDisplayMessage (Private)

- (instancetype)initWithMessageType:(WPInAppMessagingDisplayMessageType)messageType
                        triggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                            payload:(NSDictionary *)payload;


@end

@interface WPInAppMessagingModalDisplay (Private)

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          titleText:(NSString *)title
                           bodyText:(NSString *)bodyText
                          textColor:(UIColor *)textColor
                    backgroundColor:(UIColor *)backgroundColor
                          imageData:(nullable WPInAppMessagingImageData *)imageData
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                       actionButton:(nullable WPInAppMessagingActionButton *)actionButton
                             action:(nullable WPAction *)action
                closeButtonPosition:(WPInAppMessagingCloseButtonPosition)closeButtonPosition;

@end

@interface WPInAppMessagingBannerDisplay (Private)

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          titleText:(NSString *)title
                           bodyText:(NSString *)bodyText
                          textColor:(UIColor *)textColor
                    backgroundColor:(UIColor *)backgroundColor
                          imageData:(nullable WPInAppMessagingImageData *)imageData
                     bannerPosition:(WPInAppMessagingBannerPosition)bannerPosition
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                             action:(nullable WPAction *)action;

@end

@interface WPInAppMessagingImageOnlyDisplay (Private)

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          imageData:(nullable WPInAppMessagingImageData *)imageData
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                             action:(nullable WPAction *)action
                closeButtonPosition:(WPInAppMessagingCloseButtonPosition)closeButtonPosition;

@end

@interface WPInAppMessagingWebViewDisplay ()

@property(nonatomic, nonnull, strong, readonly) WKWebView *webView;

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          webView:(WKWebView *)webView
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                             action:(nullable WPAction *)action
                closeButtonPosition:(WPInAppMessagingCloseButtonPosition)closeButtonPosition;

@end


NS_ASSUME_NONNULL_END
