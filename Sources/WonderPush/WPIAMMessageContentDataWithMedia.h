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
#import <WonderPush/WPInAppMessagingRendering.h>
#import "WPIAMMessageContentData.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * An implementation for protocol WPIAMMessageContentData. This class takes a image url
 * and fetch it over the network to retrieve the image data.
 */
@interface WPIAMMessageContentDataWithMedia : NSObject <WPIAMMessageContentData>
/**
 * Create an instance which uses NSURLSession to do the image data fetching.
 *
 * @param title Message title text.
 * @param body Message body text.
 * @param actionButtonText Text for action button.
 * @param action action.
 * @param imageURL  the url to the image. It can be nil to indicate the non-image in-app
 *                  message case.
 * @param URLSession can be nil in which case the class would create NSURLSession
 *                   internally to perform the network request. Having it here so that
 *                   it's easier for doing mocking with unit testing.
 */
- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
           secondaryActionButtonText:(nullable NSString *)secondaryActionButtonText
                              action:(nullable WPAction *)action
                     secondaryAction:(nullable WPAction *)secondaryAction
                            imageURL:(nullable NSURL *)imageURL
                   landscapeImageURL:(nullable NSURL *)landscapeImageURL
                              webURL:(nullable NSURL *)webURL
                 closeButtonPosition:(WPIAMCloseButtonPosition)closeButtonPosition
                      bannerPosition:(WPIAMBannerPosition)bannerPosition
                      entryAnimation:(WPIAMEntryAnimation)entryAnimation
                       exitAnimation:(WPIAMExitAnimation)exitAnimation
                     usingURLSession:(nullable NSURLSession *)URLSession;
@end
NS_ASSUME_NONNULL_END
