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

#import <Foundation/Foundation.h>

#import <WonderPush/WPInAppMessagingRendering.h>
#import "WPInAppMessagingRenderingPrivate.h"

@implementation WPInAppMessagingDisplayMessage

- (instancetype)initWithMessageType:(WPInAppMessagingDisplayMessageType)messageType
                        triggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                            payload:(nonnull NSDictionary *)payload {
    if (self = [super init]) {
        _type = messageType;
        _triggerType = triggerType;
        _payload = [payload isKindOfClass:NSDictionary.class] ? payload : [NSDictionary new];
        _entryAnimation = entryAnimation;
        _exitAnimation = exitAnimation;
    }
    return self;
}
@end

@implementation WPInAppMessagingCardDisplay

- (void)setBody:(NSString *_Nullable)body {
    _body = body;
}

- (void)setLandscapeImageData:(WPInAppMessagingImageData *_Nullable)landscapeImageData {
    _landscapeImageData = landscapeImageData;
}

- (void)setSecondaryActionButton:(WPInAppMessagingActionButton *_Nullable)secondaryActionButton {
    _secondaryActionButton = secondaryActionButton;
}

- (void)setSecondaryAction:(WPAction *_Nullable)secondaryAction {
    _secondaryAction = secondaryAction;
}

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          titleText:(NSString *)title
                          textColor:(UIColor *)textColor
                  portraitImageData:(WPInAppMessagingImageData *)portraitImageData
                    backgroundColor:(UIColor *)backgroundColor
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                primaryActionButton:(WPInAppMessagingActionButton *)primaryActionButton
                      primaryAction:(WPAction *)primaryAction {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self = [super initWithMessageType:WPInAppMessagingDisplayMessageTypeCard
                              triggerType:triggerType
                           entryAnimation:entryAnimation
                            exitAnimation:exitAnimation
                                  payload:payload]) {
#pragma clang diagnostic pop
        _title = title;
        _textColor = textColor;
        _portraitImageData = portraitImageData;
        _displayBackgroundColor = backgroundColor;
        _primaryActionButton = primaryActionButton;
        _primaryAction = primaryAction;
    }
    return self;
}

@end

@implementation WPInAppMessagingBannerDisplay
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
                             action:(nullable WPAction *)action {
    if (self = [super initWithMessageType:WPInAppMessagingDisplayMessageTypeBanner
                              triggerType:triggerType
                           entryAnimation:entryAnimation
                            exitAnimation:exitAnimation
                                  payload:payload]) {
        _title = title;
        _bodyText = bodyText;
        _textColor = textColor;
        _displayBackgroundColor = backgroundColor;
        _imageData = imageData;
        _action = action;
        _bannerPosition = bannerPosition;
    }
    return self;
}
@end

@implementation WPInAppMessagingModalDisplay

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
                closeButtonPosition:(WPInAppMessagingCloseButtonPosition)closeButtonPosition {
    if (self = [super initWithMessageType:WPInAppMessagingDisplayMessageTypeModal
                              triggerType:triggerType
                           entryAnimation:entryAnimation
                            exitAnimation:exitAnimation
                                  payload:payload]) {
        _title = title;
        _bodyText = bodyText;
        _textColor = textColor;
        _displayBackgroundColor = backgroundColor;
        _imageData = imageData;
        _actionButton = actionButton;
        _action = action;
        _closeButtonPosition = closeButtonPosition;
    }
    return self;
}
@end

@implementation WPInAppMessagingImageOnlyDisplay

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          imageData:(nullable WPInAppMessagingImageData *)imageData
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                             action:(nullable WPAction *)action
                closeButtonPosition:(WPInAppMessagingCloseButtonPosition)closeButtonPosition {
    if (self = [super initWithMessageType:WPInAppMessagingDisplayMessageTypeModal
                              triggerType:triggerType
                           entryAnimation:entryAnimation
                            exitAnimation:exitAnimation
                                  payload:payload]) {
        _imageData = imageData;
        _action = action;
        _closeButtonPosition = closeButtonPosition;
    }
    return self;
}
@end

@implementation WPInAppMessagingWebViewDisplay

- (instancetype)initWithTriggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                            payload:(NSDictionary *)payload
                          webURL:(nullable NSURL *)webURL
                     entryAnimation:(WPInAppMessagingEntryAnimation)entryAnimation
                      exitAnimation:(WPInAppMessagingExitAnimation)exitAnimation
                             action:(nullable WPAction *)action
                closeButtonPosition:(WPInAppMessagingCloseButtonPosition)closeButtonPosition {
    if (self = [super initWithMessageType:WPInAppMessagingDisplayMessageTypeModal
                              triggerType:triggerType
                           entryAnimation:entryAnimation
                            exitAnimation:exitAnimation
                                  payload:payload]) {
        _webURL = webURL;
        _action = action;
        _closeButtonPosition = closeButtonPosition;
    }
    return self;
}
@end

@implementation WPInAppMessagingActionButton

- (instancetype)initWithButtonText:(NSString *)btnText
                   buttonTextColor:(UIColor *)textColor
                   backgroundColor:(UIColor *)bkgColor {
    if (self = [super init]) {
        _buttonText = btnText;
        _buttonTextColor = textColor;
        _buttonBackgroundColor = bkgColor;
    }
    return self;
}
@end

@implementation WPInAppMessagingImageData
- (instancetype)initWithImageURL:(NSString *)imageURL imageData:(NSData *)imageData {
    if (self = [super init]) {
        _imageURL = imageURL;
        _imageRawData = imageData;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    WPInAppMessagingImageData *imageData = [[[self class] allocWithZone:zone] init];
    imageData->_imageURL = [_imageURL copyWithZone:zone];
    imageData->_imageRawData = [_imageRawData copyWithZone:zone];
    
    return imageData;
}

@end
