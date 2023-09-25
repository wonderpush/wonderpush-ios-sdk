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

@class WPApp;

#import "WPInAppMessagingRendering.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * The root object for in-app messaging iOS SDK.
 **/
NS_SWIFT_NAME(InAppMessaging)
@interface WPInAppMessaging : NSObject
/** @fn inAppMessaging
    @brief Gets the singleton WPInAppMessaging object
    settings.
*/
+ (WPInAppMessaging *)inAppMessaging NS_SWIFT_NAME(inAppMessaging());

/**
 *  Unavailable. Use +inAppMessaging instead.
 */
- (instancetype)init __attribute__((unavailable("Use +inAppMessaging instead.")));

/**
 * A boolean flag that can be used to suppress messaging display at runtime. It's
 * initialized to false at app startup. Once set to true, IAM SDK would stop rendering any
 * new messages until it's set back to false.
 */
@property(nonatomic, assign) BOOL messageDisplaySuppressed;

/**
 * This is the display component that will be used by InAppMessaging to render messages.
 * If it's nil (the default case when InAppMessaging SDK starts), InAppMessaging
 * would only perform other non-rendering flows (fetching messages for example). SDK
 * InAppMessagingDisplay would set itself as the display component if it's included by
 * the app. Any other custom implementation of WPInAppMessagingDisplay would need to set this
 * property so that it can be used for rendering IAM message UIs.
 */
@property(nonatomic, weak) id<WPInAppMessagingDisplay> messageDisplayComponent;

/**
 * This delegate should be set on the app side to receive message lifecycle events in app runtime.
 */
@property(nonatomic, weak) id<WPInAppMessagingDisplayDelegate> delegate;

@end
NS_ASSUME_NONNULL_END
