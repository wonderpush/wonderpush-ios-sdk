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

@class WPIAMMessageDefinition;
@class WPIAMMessageRenderData;
@protocol WPIAMTimeFetcher;

NS_ASSUME_NONNULL_BEGIN

// Class responsible for parsing the json response data from the restful API endpoint
// for serving eligible messages for the current SDK clients.
@interface WPIAMFetchResponseParser : NSObject

// Turn the API response into a number of WPIAMMessageDefinition objects. If any of them is invalid
// it would be ignored and not represented in the response array.
// @param discardCount if not nil, it would contain, on return, the number of invalid messages
// detected uring parsing.
// @param fetchWaitTime would be non nil if fetch wait time data is found in the api response.
+ (NSArray<WPIAMMessageDefinition *> *)parseAPIResponseDictionary:(NSDictionary *)responseDict
                                                discardedMsgCount:(NSInteger *)discardCount;
+ (WPIAMMessageDefinition *)convertToMessageDefinitionWithCampaignDict:(NSDictionary *)campaignDict;
+ (WPIAMMessageRenderData * _Nullable) renderDataFromNotificationDict:(NSDictionary *)notificationDict isTestMessage:(BOOL)isTestMessage;
@end
NS_ASSUME_NONNULL_END
