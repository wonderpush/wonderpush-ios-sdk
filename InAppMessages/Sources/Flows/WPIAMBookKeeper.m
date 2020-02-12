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

#import "WPCore+InAppMessaging.h"
#import "WPIAMBookKeeper.h"
#import "WonderPush_private.h"

NSString *const WPIAM_UserDefaultsKeyForImpressions = @"wonderpush-iam-message-impressions";
NSString *const WPIAM_UserDefaultsKeyForLastImpressionTimestamp = @"wonderpush-iam-last-impression-timestamp";
NSString *WPIAM_UserDefaultsKeyForLastFetchTimestamp = @"wonderpush-iam-last-fetch-timestamp";

// The two keys used to map WPIAMImpressionRecord object to a NSDictionary object for
// persistence.
// These keys will be part of a WonderPush event payload, so type prefixes are required.
NSString *const WPIAM_ImpressionDictKeyForTimestampMilliseconds = @"impressionTime";
NSString *const WPIAM_ImpressionDictKeyForReportingData = @"reportingData";

static NSString *const kUserDefaultsKeyForFetchWaitTime = @"wonderpush-iam-fetch-wait-time";

// TODO: change this to 24 hours when we really fetch from a server.
static NSTimeInterval kDefaultFetchWaitTimeInSeconds = 60; //24 * 60 * 60;

// 3 days
static NSTimeInterval kMaxFetchWaitTimeInSeconds = 3 * 24 * 60 * 60;

@interface WPIAMBookKeeperViaUserDefaults ()
@property(nonatomic) double lastDisplayTime;
@property(nonatomic) double lastFetchTime;
@property(nonatomic) double nextFetchWaitTime;
@property(nonatomic, nonnull) NSUserDefaults *defaults;
@end

@interface WPIAMImpressionRecord ()
- (instancetype)initWithStorageDictionary:(NSDictionary *)dict;
@end

@implementation WPIAMImpressionRecord

- (instancetype)initWithReportingData:(WPReportingData *)reportingData
              impressionTimeInSeconds:(long)impressionTime {
    if (self = [super init]) {
        _reportingData = reportingData;
        _impressionTimeInSeconds = impressionTime;
    }
    return self;
}

- (instancetype)initWithStorageDictionary:(NSDictionary *)dict {
    id timestamp = dict[WPIAM_ImpressionDictKeyForTimestampMilliseconds];
    id reportingDataDict = dict[WPIAM_ImpressionDictKeyForReportingData];

    if (![timestamp isKindOfClass:[NSNumber class]] || ![reportingDataDict isKindOfClass:[NSDictionary class]]) {
        WPLogDebug(
                    @"Incorrect data in the dictionary object for creating a WPIAMImpressionRecord"
                    " object");
        return nil;
    } else {
        WPReportingData *reportingData = [[WPReportingData alloc] initWithDictionary:reportingDataDict];
        return [self initWithReportingData:reportingData
                   impressionTimeInSeconds:((NSNumber *)timestamp).longValue / 1000l];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ impressed at %ld in seconds", self.reportingData,
            self.impressionTimeInSeconds];
}
@end

@implementation WPIAMBookKeeperViaUserDefaults

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    if (self = [super init]) {
        _defaults = userDefaults;
        
        // ok if it returns 0 due to the entry being absent
        _lastDisplayTime = [_defaults doubleForKey:WPIAM_UserDefaultsKeyForLastImpressionTimestamp];
        _lastFetchTime = [_defaults doubleForKey:WPIAM_UserDefaultsKeyForLastFetchTimestamp];
        
        id fetchWaitTimeEntry = [_defaults objectForKey:kUserDefaultsKeyForFetchWaitTime];
        
        if (![fetchWaitTimeEntry isKindOfClass:NSNumber.class]) {
            // This corresponds to the case there is no wait time entry is set in user defaults yet
            _nextFetchWaitTime = kDefaultFetchWaitTimeInSeconds;
        } else {
            _nextFetchWaitTime = ((NSNumber *)fetchWaitTimeEntry).doubleValue;
            WPLogDebug(
                        @"Next fetch wait time loaded from user defaults is %lf", _nextFetchWaitTime);
        }
    }
    return self;
}

// A helper function for reading and verifying the stored array data for impressions
// in UserDefaults. It returns nil if it does not exist or fail to pass the data type
// checking.
- (NSArray *)fetchImpressionArrayFromStorage {
    id impressionsData = [self.defaults objectForKey:WPIAM_UserDefaultsKeyForImpressions];
    
    if (impressionsData && ![impressionsData isKindOfClass:[NSArray class]]) {
        WPLog(
                      @"Found non-array data from impression userdefaults storage with key %@",
                      WPIAM_UserDefaultsKeyForImpressions);
        return nil;
    }
    return (NSArray *)impressionsData;
}

- (void)recordNewImpressionForReportingData:(WPReportingData *)reportingData
                withStartTimestampInSeconds:(double)timestamp {
    @synchronized(self) {
        NSArray *oldImpressions = [self fetchImpressionArrayFromStorage];
        // oldImpressions could be nil at the first time
        NSMutableArray *newImpressions =
        oldImpressions ? [oldImpressions mutableCopy] : [[NSMutableArray alloc] init];
        
        // Two cases
        //    If a prior impression exists for that campaignId, update its impression timestamp
        //    If a prior impression for that campaignId does not exist, add a new entry for the
        //    campaignId.
        
        NSMutableDictionary *newImpressionEntry = [NSMutableDictionary dictionaryWithDictionary:@{
            WPIAM_ImpressionDictKeyForReportingData : reportingData.dictValue,
            WPIAM_ImpressionDictKeyForTimestampMilliseconds : [NSNumber numberWithLong:(long)(timestamp * 1000)]
        }];
        BOOL oldImpressionRecordFound = NO;
        
        for (int i = 0; i < newImpressions.count; i++) {
            if ([newImpressions[i] isKindOfClass:[NSDictionary class]]) {
                NSDictionary *currentItem = (NSDictionary *)newImpressions[i];
                id currentItemReportingDataDict = currentItem[WPIAM_ImpressionDictKeyForReportingData];
                if ([currentItemReportingDataDict isKindOfClass:[NSDictionary class]]) {
                    WPReportingData *currentItemReportingData = [[WPReportingData alloc] initWithDictionary:currentItemReportingDataDict];
                    if ([reportingData.campaignId isEqualToString:currentItemReportingData.campaignId]
                        && [reportingData.notificationId isEqualToString:currentItemReportingData.notificationId]) {
                        WPLogDebug(
                                    @"Updating timestamp of existing impression record to be %f for "
                                    "campaign %@, notification %@",
                                    timestamp, reportingData.campaignId, reportingData.notificationId);
                        
                        [newImpressions replaceObjectAtIndex:i withObject:newImpressionEntry];
                        oldImpressionRecordFound = YES;
                        break;
                    }
                }
            }
        }
        
        if (!oldImpressionRecordFound) {
            WPLogDebug(@"Insert the first impression record for campaign %@, notification %@ with timestamp in milliseconds as %f",
                       reportingData.campaignId, reportingData.notificationId, timestamp);
            [newImpressions addObject:newImpressionEntry];
        }
        
        [self.defaults setObject:newImpressions forKey:WPIAM_UserDefaultsKeyForImpressions];
        [self.defaults setDouble:timestamp forKey:WPIAM_UserDefaultsKeyForLastImpressionTimestamp];
        self.lastDisplayTime = timestamp;
        NSMutableDictionary *eventData = [NSMutableDictionary new];
        [eventData addEntriesFromDictionary:reportingData.dictValue];
        eventData[@"timestamp"] = [NSNumber numberWithLong:(long)(timestamp * 1000)];
        [WonderPush trackInternalEvent:@"@INAPP_VIEWED" eventData:[NSDictionary dictionaryWithDictionary:eventData] customData:nil];
    }
}

- (NSArray<WPIAMImpressionRecord *> *)getImpressions {
    NSArray<NSDictionary *> *impressionsFromStorage = [self fetchImpressionArrayFromStorage];
    
    NSMutableArray<WPIAMImpressionRecord *> *resultArray = [[NSMutableArray alloc] init];
    
    for (NSDictionary *next in impressionsFromStorage) {
        WPIAMImpressionRecord *nextImpression =
        [[WPIAMImpressionRecord alloc] initWithStorageDictionary:next];
        [resultArray addObject:nextImpression];
    }
    
    return resultArray;
}

- (NSArray<NSString *> *)getCampaignIdsFromImpressions {
    NSArray<NSDictionary *> *impressionsFromStorage = [self fetchImpressionArrayFromStorage];
    
    NSMutableArray<NSString *> *resultArray = [[NSMutableArray alloc] init];
    
    for (NSDictionary *next in impressionsFromStorage) {
        WPReportingData *reportingData = [[WPReportingData alloc] initWithDictionary:next[@"reportingData"]];
        if (reportingData.campaignId) [resultArray addObject:reportingData.campaignId];
    }
    
    return resultArray;
}

- (void)recordNewFetchWithFetchCount:(NSInteger)fetchedMsgCount
              withTimestampInSeconds:(double)fetchTimestamp
                   nextFetchWaitTime:(nullable NSNumber *)nextFetchWaitTime;
{
    [self.defaults setDouble:fetchTimestamp forKey:WPIAM_UserDefaultsKeyForLastFetchTimestamp];
    self.lastFetchTime = fetchTimestamp;
    
    if (nextFetchWaitTime != nil) {
        if (nextFetchWaitTime.doubleValue > kMaxFetchWaitTimeInSeconds) {
            WPLog(
                       @"next fetch wait time %lf is too large. Ignore it.",
                       nextFetchWaitTime.doubleValue);
        } else {
            WPLogDebug(
                        @"Setting next fetch wait time as %lf from fetch response.",
                        nextFetchWaitTime.doubleValue);
            self.nextFetchWaitTime = nextFetchWaitTime.doubleValue;
            [self.defaults setObject:nextFetchWaitTime forKey:kUserDefaultsKeyForFetchWaitTime];
        }
    }
}

- (void)cleanupImpressions {
    [self.defaults setObject:@[] forKey:WPIAM_UserDefaultsKeyForImpressions];
}

- (void)cleanupFetchRecords {
    [self.defaults setDouble:0 forKey:WPIAM_UserDefaultsKeyForLastFetchTimestamp];
    self.lastFetchTime = 0;
}
@end