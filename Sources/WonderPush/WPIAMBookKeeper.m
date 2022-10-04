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
#import "WPConfiguration.h"

NSString *const WPIAM_UserDefaultsKeyForImpressions = @"wonderpush-iam-message-impressions";
NSString *const WPIAM_UserDefaultsKeyForLastImpressionTimestamp = @"wonderpush-iam-last-impression-timestamp";

// The keys used to map WPIAMImpressionRecord object to a NSDictionary object for
// persistence.
NSString *const WPIAM_ImpressionDictKeyForCount = @"impressionCount";
NSString *const WPIAM_ImpressionDictKeyForLastImpressionDateTimestamp = @"lastImpressionDate";
NSString *const WPIAM_ImpressionDictKeyForReportingData = @"reportingData";

@interface WPIAMBookKeeperViaUserDefaults ()
@property(nonatomic, nonnull) NSUserDefaults *defaults;
@end

@interface WPIAMImpressionRecord ()
- (instancetype)initWithStorageDictionary:(NSDictionary *)dict;
@end

@implementation WPIAMImpressionRecord

- (instancetype)initWithReportingData:(WPReportingData *)reportingData lastImpressionTimestamp:(NSTimeInterval)lastImpressionTimestamp impressionCount:(NSInteger)impressionCount {
    if (self = [super init]) {
        _reportingData = reportingData;
        _impressionCount = impressionCount;
        _lastImpressionTimestamp = lastImpressionTimestamp;
    }
    return self;
}

- (instancetype)initWithStorageDictionary:(NSDictionary *)dict {
    id reportingDataDict = dict[WPIAM_ImpressionDictKeyForReportingData];
    id lastImpressionTimestamp = dict[WPIAM_ImpressionDictKeyForLastImpressionDateTimestamp];
    id impressionCount = dict[WPIAM_ImpressionDictKeyForCount];

    if (![reportingDataDict isKindOfClass:[NSDictionary class]]) {
        WPLogDebug(
                    @"Incorrect data in the dictionary object for creating a WPIAMImpressionRecord"
                    " object");
        return nil;
    } else {
        WPReportingData *reportingData = [[WPReportingData alloc] initFromSerialized:reportingDataDict];
        return [self initWithReportingData:reportingData
                   lastImpressionTimestamp:lastImpressionTimestamp ? [lastImpressionTimestamp doubleValue] : 0
                           impressionCount:impressionCount ? [impressionCount integerValue] : 1];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ impressed at %f in seconds", self.reportingData,
            self.lastImpressionTimestamp];
}
@end

@implementation WPIAMBookKeeperViaUserDefaults

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    if (self = [super init]) {
        _defaults = userDefaults;
    }
    return self;
}

- (NSTimeInterval)lastRateLimitedInAppDisplayTime {
    // ok if it returns 0 due to the entry being absent
    return [_defaults doubleForKey:WPIAM_UserDefaultsKeyForLastImpressionTimestamp];
}

- (void)setLastRateLimitedInAppDisplayTime:(NSTimeInterval)lastRateLimitedInAppDisplayTime {
    [_defaults setDouble:lastRateLimitedInAppDisplayTime forKey:WPIAM_UserDefaultsKeyForLastImpressionTimestamp];
    [_defaults synchronize];
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
        //    If a prior impression exists for that campaignId, update its impression timestamp and the impression count
        //    If a prior impression for that campaignId does not exist, add a new entry for the
        //    campaignId.
        
        NSNumber *dateTimestamp = [NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970];
        NSMutableDictionary *newImpressionEntry = [NSMutableDictionary dictionaryWithDictionary:@{
            WPIAM_ImpressionDictKeyForReportingData: reportingData.serializationDictValue,
            WPIAM_ImpressionDictKeyForCount: @1,
            WPIAM_ImpressionDictKeyForLastImpressionDateTimestamp: dateTimestamp,
        }];
        BOOL oldImpressionRecordFound = NO;
        
        for (int i = 0; i < newImpressions.count; i++) {
            if ([newImpressions[i] isKindOfClass:[NSDictionary class]]) {
                NSDictionary *currentItem = (NSDictionary *)newImpressions[i];
                id currentItemReportingDataDict = currentItem[WPIAM_ImpressionDictKeyForReportingData];
                if ([currentItemReportingDataDict isKindOfClass:[NSDictionary class]]) {
                    WPReportingData *currentItemReportingData = [[WPReportingData alloc] initFromSerialized:currentItemReportingDataDict];
                    if (
                        (reportingData.campaignId == currentItemReportingData.campaignId || [reportingData.campaignId isEqualToString:currentItemReportingData.campaignId])
                        && (reportingData.notificationId == currentItemReportingData.notificationId || [reportingData.notificationId isEqualToString:currentItemReportingData.notificationId])
                    ) {
                        WPLogDebug(
                                    @"Updating timestamp of existing impression record to be %f for "
                                    "campaign %@, notification %@",
                                    timestamp, reportingData.campaignId, reportingData.notificationId);
                        newImpressionEntry[WPIAM_ImpressionDictKeyForCount] = [NSNumber numberWithInteger:currentItem[WPIAM_ImpressionDictKeyForCount] ? [currentItem[WPIAM_ImpressionDictKeyForCount] integerValue] + 1 : 2 ];
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
            [newImpressions addObject:[NSDictionary dictionaryWithDictionary:newImpressionEntry]];
        }
        
        [self.defaults setObject:[NSArray arrayWithArray:newImpressions] forKey:WPIAM_UserDefaultsKeyForImpressions];
        [self.defaults synchronize];
        NSMutableDictionary *eventData = [NSMutableDictionary new];
        [reportingData fillEventDataInto:eventData attributionReason:WPReportingAttributionReasonInAppViewed];
        eventData[@"actionDate"] = [NSNumber numberWithLong:(long)(timestamp * 1000)];
        
        [WonderPush countInternalEvent:@"@INAPP_VIEWED"
                             eventData:[NSDictionary dictionaryWithDictionary:eventData]
                            customData:nil];
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
    
    return [resultArray copy];
}

- (NSArray<NSString *> *)getCampaignIdsFromImpressions {
    NSArray<NSDictionary *> *impressionsFromStorage = [self fetchImpressionArrayFromStorage];
    
    NSMutableArray<NSString *> *resultArray = [[NSMutableArray alloc] init];
    
    for (NSDictionary *next in impressionsFromStorage) {
        WPReportingData *reportingData = [[WPReportingData alloc] initFromSerialized:next[WPIAM_ImpressionDictKeyForReportingData]];
        if (reportingData.campaignId) [resultArray addObject:reportingData.campaignId];
    }
    
    return [resultArray copy];
}

- (void)cleanupImpressions {
    [self.defaults setObject:@[] forKey:WPIAM_UserDefaultsKeyForImpressions];
}

@end
