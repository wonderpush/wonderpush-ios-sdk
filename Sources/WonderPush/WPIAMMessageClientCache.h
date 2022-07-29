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
#import "WPIAMFetchResponseParser.h"
#import "WPIAMMessageDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@class WPIAMDisplayCheckOnAnalyticEventsFlow;

@interface WPIAMContextualTrigger
@property(nonatomic, copy, readonly) NSString *eventName;
@end

@interface WPIAMContextualTriggerListener
+ (void)listenForTriggers:(NSArray<WPIAMContextualTrigger *> *)triggers
             withCallback:(void (^)(WPIAMContextualTrigger *matchedTrigger))callback;
@end

@protocol WPIAMCacheDataObserver
- (void)dataChanged;
@end

// This class serves as an in-memory cache of the messages that would be searched for finding next
// message to be rendered. Its content can be loaded from client persistent storage upon SDK
// initialization and then updated whenever a new fetch is made to server to receive the last
// list. In the case a message has been rendered, it's removed from the cache so that it's not
// considered next time for the message search.
//
// This class is also responsible for setting up and tearing down appropriate analytics event
// listening flow based on whether the current active event list contains any analytics event
// trigger based messages.
//
// This class exists so that we can do message match more efficiently (in-memory search vs search
// in local persistent storage) by using appropriate in-memory data structure.
@interface WPIAMMessageClientCache : NSObject

// used to inform the analytics event display check flow about whether it should start/stop
// analytics event listening based on the latest message definitions
// make it weak to avoid retaining cycle
@property(nonatomic, weak, nullable)
    WPIAMDisplayCheckOnAnalyticEventsFlow *analycisEventDislayCheckFlow;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBookkeeper:(id<WPIAMBookKeeper>)bookKeeper;

// Returns YES if there are any test messages in the cache.
- (BOOL)hasTestMessage;

// read all the messages as a copy stored in cache
- (NSArray<WPIAMMessageDefinition *> *)allRegularMessages;

// clients that are to display messages should use nextOnAppOpenDisplayMsg or
// nextOnEventDisplayMsg:count: to fetch the next eligible message and use
// removeMessagesWithCampaignId to remove it from cache once the message has been correctly rendered

// Fetch next eligible messages that are appropriate for display at app launch time
- (nullable WPIAMMessageDefinition *)nextOnAppLaunchDisplayMsg;
// Fetch next eligible messages that are appropriate for display at app open time
- (nullable WPIAMMessageDefinition *)nextOnAppOpenDisplayMsg;
// Fetch next eligible message that matches the event triggering condition
- (nullable WPIAMMessageDefinition *)nextOnEventDisplayMsg:(NSString *)eventName count:(NSInteger)count;

// Call this after a message has been rendered to remove it from the cache.
- (void)removeMessagesWithCampaignId:(NSString *)campaignId;

// reset messages data
- (void)setMessageData:(NSArray<WPIAMMessageDefinition *> *)messages;
// load messages from persistent storage
- (void)loadMessagesFromRemoteConfigWithCompletion:(void (^ _Nullable)(BOOL success))completion;
@end
NS_ASSUME_NONNULL_END
