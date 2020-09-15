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
#import "WPReportingData.h"

NS_ASSUME_NONNULL_BEGIN
@interface WPIAMImpressionRecord : NSObject
@property(nonatomic, readonly) WPReportingData *reportingData;
@property(nonatomic, readonly) long impressionTimeInSeconds;
@property(nonatomic, readonly) NSTimeInterval lastImpressionTimestamp;
@property(nonatomic, readonly) NSInteger impressionCount;

- (NSString *)description;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithReportingData:(WPReportingData *)reportingData
              impressionTimeInSeconds:(long)impressionTime
              lastImpressionTimestamp:(NSTimeInterval)lastImpressionTimestamp
                      impressionCount:(NSInteger)impressionCount NS_DESIGNATED_INITIALIZER;
@end

// this protocol defines the interface for classes that can be used to track info regarding
// display of iam messages. The info tracked here can be used to decide if it's due for
// next display of iam messages.
@protocol WPIAMBookKeeper
@property(nonatomic, readonly) double lastDisplayTime;

// only call this when it's considered to be a valid impression (for example, meeting the minimum
// display time requirement).
- (void)recordNewImpressionForReportingData:(WPReportingData *)reportingData
                withStartTimestampInSeconds:(double)timestamp;

// fetch the impression list
- (NSArray<WPIAMImpressionRecord *> *)getImpressions;

// For certain clients, they only need to get the list of the message ids in existing impression
// records. This is a helper method for that.
- (NSArray<NSString *> *)getCampaignIdsFromImpressions;
@end

// implementation of WPIAMBookKeeper protocol by storing data within iOS UserDefaults.
// TODO: switch to something else if there is risks for the data being unintentionally deleted by
// the app
@interface WPIAMBookKeeperViaUserDefaults : NSObject <WPIAMBookKeeper>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults NS_DESIGNATED_INITIALIZER;

// for testing, don't use them for production purpose
- (void)cleanupImpressions;

@end

NS_ASSUME_NONNULL_END
