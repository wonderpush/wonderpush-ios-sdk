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

// A class for wrapping the interactions for retrieving client side info to be used in request
// parameter for interacting with servers.

NS_ASSUME_NONNULL_BEGIN
@interface WPIAMClientInfoFetcher : NSObject
// Following are synchronous methods for fetching data
- (nullable NSString *)getDeviceLanguageCode;
- (nullable NSString *)getAppVersion;
- (nullable NSString *)getOSVersion;
- (nullable NSString *)getOSMajorVersion;
- (nullable NSString *)getTimezone;
@end
NS_ASSUME_NONNULL_END
