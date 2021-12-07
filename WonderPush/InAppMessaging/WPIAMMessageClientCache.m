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
#import "WPIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "WPIAMDisplayTriggerDefinition.h"
#import "WPIAMFetchResponseParser.h"
#import "WPIAMMessageClientCache.h"
#import "WonderPush_private.h"
#import "WPSPSegmenter.h"
#import "WPNSUtil.h"

@interface WPIAMMessageClientCache ()

// messages not for client-side testing
@property(nonatomic) NSMutableArray<WPIAMMessageDefinition *> *regularMessages;
// messages for client-side testing
@property(nonatomic) NSMutableArray<WPIAMMessageDefinition *> *testMessages;
@property(nonatomic) NSMutableSet<NSString *> *wonderpushEventsToWatch;
@property(nonatomic) id<WPIAMBookKeeper> bookKeeper;

@end

// Methods doing read and write operations on messages field is synchronized to avoid
// race conditions like change the array while iterating through it
@implementation WPIAMMessageClientCache
- (instancetype)initWithBookkeeper:(id<WPIAMBookKeeper>)bookKeeper {
    if (self = [super init]) {
        _bookKeeper = bookKeeper;
    }
    return self;
}

// reset messages data
- (void)setMessageData:(NSArray<WPIAMMessageDefinition *> *)messages {
    @synchronized(self) {
        
        NSDictionary<NSString *, WPIAMImpressionRecord *> *impressionRecords = [self getImpressionRecords];
        
        NSMutableArray<WPIAMMessageDefinition *> *regularMessages = [[NSMutableArray alloc] init];
        self.testMessages = [[NSMutableArray alloc] init];
        
        // split between test vs non-test messages
        for (WPIAMMessageDefinition *next in messages) {
            if (next.isTestMessage) {
                [self.testMessages addObject:next];
            } else {
                [regularMessages addObject:next];
            }
        }
        
        // while resetting the whole message set, we do prefiltering based on the impressions
        // data to get rid of messages we don't care so that the future searches are more efficient
        NSPredicate *notOverImpressedPredicate = [NSPredicate
                                                  predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            WPIAMMessageDefinition *message = (WPIAMMessageDefinition *)evaluatedObject;
            NSString *campaignId = message.renderData.reportingData.campaignId;
            if (!campaignId) return NO;
            WPIAMImpressionRecord *impressionRecord = impressionRecords[campaignId];
            NSInteger impressionCount = impressionRecord ? impressionRecord.impressionCount : 0;
            return impressionCount < message.capping.maxImpressions;
        }];
        
        self.regularMessages = [[regularMessages filteredArrayUsingPredicate:notOverImpressedPredicate] mutableCopy];
        [self setupWonderPushEventListening];
    }
    
//    WPLogDebug(
//                @"There are %lu test messages and %lu regular messages and "
//                "%lu events to watch after "
//                "resetting the message cache",
//                (unsigned long)self.testMessages.count, (unsigned long)self.regularMessages.count,
//                (unsigned long)self.wonderpushEventsToWatch.count);
}

// triggered after self.messages are updated so that we can correctly enable/disable listening
// on analytics event based on current IAM message set
- (void)setupWonderPushEventListening {
    self.wonderpushEventsToWatch = [[NSMutableSet alloc] init];
    for (WPIAMMessageDefinition *nextMessage in self.regularMessages) {
        // if it's event based triggering, add it to the watch set
        for (WPIAMDisplayTriggerDefinition *nextTrigger in nextMessage.renderTriggers) {
            if (nextTrigger.triggerType == WPIAMRenderTriggerOnWonderPushEvent) {
                [self.wonderpushEventsToWatch addObject:nextTrigger.eventName];
            }
        }
    }
    
    if (self.analycisEventDislayCheckFlow) {
        if ([self.wonderpushEventsToWatch count] > 0) {
            WPLogDebug(
                        @"There are analytics event trigger based messages, enable listening");
            [self.analycisEventDislayCheckFlow start];
        } else {
//            WPLogDebug(@"No analytics event trigger based messages, disable listening");
            [self.analycisEventDislayCheckFlow stop];
        }
    }
}

- (NSArray<WPIAMMessageDefinition *> *)allRegularMessages {
    return [self.regularMessages copy];
}

- (BOOL)hasTestMessage {
    return self.testMessages.count > 0;
}

- (nullable WPIAMMessageDefinition *)nextOnAppLaunchDisplayMsg {
    return [self nextMessageForTrigger:WPIAMRenderTriggerOnAppLaunch];
}

- (nullable WPIAMMessageDefinition *)nextOnAppOpenDisplayMsg {
    @synchronized(self) {
        // always first check test message which always have higher prirority
        if (self.testMessages.count > 0) {
            WPIAMMessageDefinition *testMessage = self.testMessages[0];
            // always remove test message right away when being fetched for display
            [self.testMessages removeObjectAtIndex:0];
            WPLogDebug(
                        @"Returning a test message for app foreground display");
            return testMessage;
        }
    }
    
    // otherwise check for a message from a published campaign
    return [self nextMessageForTrigger:WPIAMRenderTriggerOnAppForeground];
}

- (nullable WPIAMMessageDefinition *)nextMessageForTrigger:(WPIAMRenderTrigger)trigger {
    return [self nextMsgMatchingCondition:^(WPIAMMessageDefinition *next) {
        return [next messageRenderedOnTrigger:trigger];
    }];
}

- (nullable WPIAMMessageDefinition *)nextOnEventDisplayMsg:(NSString *)eventName {
    if (![self.wonderpushEventsToWatch containsObject:eventName]) {
        return nil;
    }
    return [self nextMsgMatchingCondition:^(WPIAMMessageDefinition *next) {
        return [next messageRenderedOnWonderPushEvent:eventName];
    }];
}

- (NSDictionary<NSString *, WPIAMImpressionRecord *> *)getImpressionRecords {
    NSArray<WPIAMImpressionRecord *> *records = [self.bookKeeper getImpressions];
    NSMutableDictionary<NSString *, WPIAMImpressionRecord *> *result = [NSMutableDictionary new];
    for (WPIAMImpressionRecord *record in records) {
        NSString *campaignId = record.reportingData.campaignId;
        if (!campaignId) continue;
        result[campaignId] = record;
    }
    return [NSDictionary dictionaryWithDictionary:result];
}

- (nullable WPIAMMessageDefinition *)nextMsgMatchingCondition:(BOOL(^)(WPIAMMessageDefinition *))condition {
    NSDictionary<NSString *, WPIAMImpressionRecord *> *impressionRecords = [self getImpressionRecords];
    WPSPSegmenter *segmenter = [[WPSPSegmenter alloc] initWithData:[WPSPSegmenterData forCurrentUser]];
    @synchronized(self) {
        NSTimeInterval timeSince1970 = [NSDate date].timeIntervalSince1970;
        // search from the start to end in the list (which implies the display priority) for the
        // first match (some messages in the cache may not be eligible for the current display
        // message fetch
        for (WPIAMMessageDefinition *next in self.regularMessages) {
            NSString *campaignId = next.renderData.reportingData.campaignId;
            WPIAMImpressionRecord *impressionRecord = impressionRecords[campaignId];
            NSInteger impressionCount = impressionRecord ? impressionRecord.impressionCount : 0;
            NSTimeInterval timeSinceLastImpression = impressionRecord ? timeSince1970 - impressionRecord.lastImpressionTimestamp : timeSince1970;
            // message being active and message not impressed yet and the contextual trigger condition
            // match
            if ([next messageHasStarted] && ![next messageHasExpired]
                && impressionCount < next.capping.maxImpressions
                && timeSinceLastImpression > next.capping.snoozeTime
                && condition(next)) {
                if (next.segmentDefinition) {
                    @try {
                        WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:next.segmentDefinition];
                        if (![segmenter parsedSegmentMatchesInstallation:parsedSegment]) {
                            continue; // Segmentation check
                        }
                    } @catch (NSException *exception) {
                        WPLog(@"Invalid segment: %@", next.segmentDefinition);
                        // Let's not use this in-app with a buggy segment
                        continue;
                    }
                }
                return next;
            }
        }
    }
    return nil;
}

- (void)removeMessagesWithCampaignId:(NSString *)campaignId {
    if (!campaignId) return;
    NSMutableArray<WPIAMMessageDefinition *> *messagesToRemove = [NSMutableArray new];
    @synchronized(self) {
        for (WPIAMMessageDefinition *next in self.regularMessages) {
            if ([next.renderData.reportingData.campaignId isEqualToString:campaignId]) {
                [messagesToRemove addObject:next];
            }
        }
        
        if (messagesToRemove.count > 0) {
            [self.regularMessages removeObjectsInArray:[messagesToRemove copy]];
            [self setupWonderPushEventListening];
        }
    }
    
}

- (void)loadMessagesFromRemoteConfigWithCompletion:(void (^)(BOOL success))completion {
    if (!WonderPush.remoteConfigManager) {
        if (completion) completion(NO);
        return;
    }
    [WonderPush.remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {
        if (error) {
            if (completion) completion(NO);
            return;
        }
        NSDictionary *inAppConfig = [WPNSUtil dictionaryForKey:@"inAppConfig" inDictionary:config.data] ?: @{};
        NSInteger discardCount;
        NSArray<WPIAMMessageDefinition *> *messagesFromStorage = [WPIAMFetchResponseParser
                                                                  parseAPIResponseDictionary:inAppConfig
                                                                  discardedMsgCount:&discardCount];
        [self setMessageData:messagesFromStorage];
        if (completion) completion(YES);

    }];
}
@end
