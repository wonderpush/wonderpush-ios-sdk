/*
 * Copyright 2017 Google
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
#import "WPAction.h"

typedef NS_ENUM(NSInteger, WPIAMCloseButtonPosition) {
    WPIAMCloseButtonPositionOutside,
    WPIAMCloseButtonPositionInside,
    WPIAMCloseButtonPositionNone,
};

typedef NS_ENUM(NSInteger, WPIAMBannerPosition) {
    WPIAMBannerPositionTop,
    WPIAMBannerPositionBottom,
};

typedef NS_ENUM(NSInteger, WPIAMEntryAnimation) {
    WPIAMEntryAnimationScaleUp,
    WPIAMEntryAnimationFadeIn,
    WPIAMEntryAnimationSlideInFromRight,
    WPIAMEntryAnimationSlideInFromLeft,
    WPIAMEntryAnimationSlideInFromTop,
    WPIAMEntryAnimationSlideInFromBottom,
};

typedef NS_ENUM(NSInteger, WPIAMExitAnimation) {
    WPIAMExitAnimationScaleDown,
    WPIAMExitAnimationFadeOut,
    WPIAMExitAnimationSlideOutRight,
    WPIAMExitAnimationSlideOutLeft,
    WPIAMExitAnimationSlideOutUp,
    WPIAMExitAnimationSlideOutDown,
};

NS_ASSUME_NONNULL_BEGIN
/**
 * This protocol models the message content (non-ui related) data for an in-app message.
 */
@protocol WPIAMMessageContentData
@property(nonatomic, readonly, nonnull) NSString *titleText;
@property(nonatomic, readonly, nonnull) NSString *bodyText;
@property(nonatomic, readonly, nullable) NSString *actionButtonText;
@property(nonatomic, readonly, nullable) NSString *secondaryActionButtonText;
@property(nonatomic, readonly, nullable) WPAction *action;
@property(nonatomic, readonly, nullable) WPAction *secondaryAction;
@property(nonatomic, readonly, nullable) NSURL *imageURL;
@property(nonatomic, readonly, nullable) NSURL *landscapeImageURL;
@property(nonatomic, readonly) WPIAMCloseButtonPosition closeButtonPosition;
@property(nonatomic, readonly) WPIAMEntryAnimation entryAnimation;
@property(nonatomic, readonly) WPIAMExitAnimation exitAnimation;

@property(nonatomic, readonly) WPIAMBannerPosition bannerPosition;

// Load image data, which can potentially have two images (one for landscape display). If only
// one image URL exists, that image is loaded and its data is passed in the callback block.
//
// If both standard and landscape URLs exist, then both images are fetched asynchronously. If the
// standard image fails to load, an error will be returned in the callback block and both image data
// slots will be empty.
// If only the landscape image fails to load, the standard image will be returned in the callback
// block and the error will be nil.
// If no error happens and the imageData parameter is nil, it indicates the case that there is no
// image associated with the message.
- (void)loadImageDataWithBlock:(void (^)(NSData *_Nullable imageData,
                                         NSData *_Nullable landscapeImageData,
                                         NSError *_Nullable error))block;

// convert to a description string of the content
- (NSString *)description;
@end
NS_ASSUME_NONNULL_END
