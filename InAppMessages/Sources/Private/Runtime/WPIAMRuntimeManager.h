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

#import "WPIAMBookKeeper.h"
#import "WPIAMDisplayExecutor.h"
#import "WPIAMMessageClientCache.h"
#import "WPIAMSDKSettings.h"
#import "WPIAMServerMsgFetchStorage.h"

NS_ASSUME_NONNULL_BEGIN
// A class for managing the objects/dependencies for supporting different IAM flows at runtime
@interface WPIAMRuntimeManager : NSObject
@property(nonatomic, nonnull) WPIAMSDKSettings *currentSetting;
@property(nonatomic, nonnull) WPIAMBookKeeperViaUserDefaults *bookKeeper;
@property(nonatomic, nonnull) WPIAMMessageClientCache *messageCache;
@property(nonatomic, nonnull) WPIAMServerMsgFetchStorage *fetchResultStorage;
@property(nonatomic, nonnull) WPIAMDisplayExecutor *displayExecutor;

// Initialize IAM SDKs and start various flows with specified settings.
- (void)startRuntimeWithSDKSettings:(WPIAMSDKSettings *)settings;

// Pause runtime flows/functions to disable SDK functions at runtime
- (void)pause;

// Resume runtime flows/functions.
- (void)resume;

// Force fetch
- (void)forceFetchInApps;

// Get the global singleton instance
+ (WPIAMRuntimeManager *)getSDKRuntimeInstance;

// a method used to suppress or allow message being displayed based on the parameter
// @param shouldSuppress if true, no new message is rendered by the sdk.
- (void)setShouldSuppressMessageDisplay:(BOOL)shouldSuppress;
@end
NS_ASSUME_NONNULL_END
