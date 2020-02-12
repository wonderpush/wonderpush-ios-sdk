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
#import "WPIAMFetchFlow.h"
#import "WPIAMRuntimeManager.h"

// the notification message to say that the fetch flow is done
NSString *const kWPIAMFetchIsDoneNotification = @"WPIAMFetchIsDoneNotification";

@interface WPIAMFetchFlow ()
@property(nonatomic) id<WPIAMTimeFetcher> timeFetcher;
@property(nonatomic) NSTimeInterval lastFetchTime;
@property(nonatomic, nonnull, readonly) WPIAMMessageClientCache *messageCache;
@property(nonatomic) id<WPIAMMessageFetcher> messageFetcher;
@property(nonatomic, nonnull, readonly) id<WPIAMBookKeeper> fetchBookKeeper;
@property(nonatomic, nonnull, readonly) WPIAMActivityLogger *activityLogger;
@property(nonatomic, nonnull, readonly) WPIAMSDKModeManager *sdkModeManager;
@property(nonatomic, nonnull, readonly) WPIAMDisplayExecutor *displayExecutor;

@end

@implementation WPIAMFetchFlow
- (instancetype)initWithMessageCache:(WPIAMMessageClientCache *)cache
                      messageFetcher:(id<WPIAMMessageFetcher>)messageFetcher
                         timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher
                          bookKeeper:(id<WPIAMBookKeeper>)fetchBookKeeper
                      activityLogger:(WPIAMActivityLogger *)activityLogger
                WPIAMSDKModeManager:(WPIAMSDKModeManager *)sdkModeManager
                     displayExecutor:(WPIAMDisplayExecutor *)displayExecutor {
    if (self = [super init]) {
        _timeFetcher = timeFetcher;
        _lastFetchTime = [fetchBookKeeper lastFetchTime];
        _messageCache = cache;
        _messageFetcher = messageFetcher;
        _fetchBookKeeper = fetchBookKeeper;
        _activityLogger = activityLogger;
        _sdkModeManager = sdkModeManager;
        _displayExecutor = displayExecutor;
    }
    return self;
}

- (void)sendFetchIsDoneNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:kWPIAMFetchIsDoneNotification
                                                        object:self];
}

- (void)handleSuccessullyFetchedMessages:(NSArray<WPIAMMessageDefinition *> *)messagesInResponse
                       withFetchWaitTime:(NSNumber *_Nullable)fetchWaitTime {
    WPLogDebug( @"%lu messages were fetched successfully.",
                (unsigned long)messagesInResponse.count);
    
    for (WPIAMMessageDefinition *next in messagesInResponse) {
        if (next.isTestMessage && self.sdkModeManager.currentMode != WPIAMSDKModeTesting) {
            WPLogDebug(
                        @"Seeing test message in fetch response. Turn "
                        "the current instance into a testing instance.");
            [self.sdkModeManager becomeTestingInstance];
        }
    }
    
    [self.messageCache setMessageData:messagesInResponse];
    
    [self.sdkModeManager registerOneMoreFetch];
    [self.fetchBookKeeper recordNewFetchWithFetchCount:messagesInResponse.count
                                withTimestampInSeconds:[self.timeFetcher currentTimestampInSeconds]
                                     nextFetchWaitTime:fetchWaitTime];
}

- (void)checkAndFetchForInitialAppLaunch:(BOOL)forInitialAppLaunch {
    NSTimeInterval intervalFromLastFetchInSeconds =
    [self.timeFetcher currentTimestampInSeconds] - self.fetchBookKeeper.lastFetchTime;
    
    WPLogDebug(
                @"Interval from last time fetch is %lf seconds", intervalFromLastFetchInSeconds);
    
    BOOL fetchIsAllowedNow = NO;
    
    if (intervalFromLastFetchInSeconds >= self.fetchBookKeeper.nextFetchWaitTime) {
        // it's enough wait time interval from last fetch.
        fetchIsAllowedNow = YES;
    } else {
        WPIAMSDKMode sdkMode = [self.sdkModeManager currentMode];
        if (sdkMode == WPIAMSDKModeNewlyInstalled || sdkMode == WPIAMSDKModeTesting) {
            WPLogDebug(
                        @"OK to fetch due to current SDK mode being %@",
                        WPIAMDescriptonStringForSDKMode(sdkMode));
            fetchIsAllowedNow = YES;
        } else {
            WPLogDebug(
                        @"Interval from last time fetch is %lf seconds, smaller than fetch wait time %lf",
                        intervalFromLastFetchInSeconds, self.fetchBookKeeper.nextFetchWaitTime);
        }
    }
    
    if (fetchIsAllowedNow) {
        // we are allowed to fetch in-app message from time interval wise
        
        WPIAMActivityRecord *record =
        [[WPIAMActivityRecord alloc] initWithActivityType:WPIAMActivityTypeCheckForFetch
                                              isSuccessful:YES
                                                withDetail:@"OK to do a fetch"
                                                 timestamp:nil];
        [self.activityLogger addLogRecord:record];
        
        WPLogDebug( @"Go ahead to fetch messages");
        
        NSTimeInterval fetchStartTime = [[NSDate date] timeIntervalSince1970];
        
        [self.messageFetcher
         fetchMessagesWithCompletion:^(NSArray<WPIAMMessageDefinition *> *_Nullable messages,
                                       NSNumber *_Nullable nextFetchWaitTime,
                                       NSInteger discardedMessageCount,
                                       NSError *_Nullable error) {
            if (error) {
                WPLog(
                              @"Error happened during message fetching %@", error);
                
                WPIAMActivityRecord *record = [[WPIAMActivityRecord alloc]
                                                initWithActivityType:WPIAMActivityTypeFetchMessage
                                                isSuccessful:NO
                                                withDetail:error.description
                                                timestamp:nil];
                [self.activityLogger addLogRecord:record];
            } else {
                double fetchOperationLatencyInMills =
                ([[NSDate date] timeIntervalSince1970] - fetchStartTime) * 1000;
                NSString *activityLogDetail = @"";
                
                if (discardedMessageCount > 0) {
                    activityLogDetail = [NSString
                                         stringWithFormat:
                                         @"%lu messages fetched with %lu messages are discarded due to data being "
                                         "invalid. It took"
                                         " %lf milliseconds",
                                         (unsigned long)messages.count,
                                         (unsigned long)discardedMessageCount,
                                         fetchOperationLatencyInMills];
                } else {
                    activityLogDetail = [NSString
                                         stringWithFormat:
                                         @"%lu messages fetched. It took"
                                         " %lf milliseconds",
                                         (unsigned long)messages.count,
                                         fetchOperationLatencyInMills];
                }
                
                WPIAMActivityRecord *record = [[WPIAMActivityRecord alloc]
                                                initWithActivityType:WPIAMActivityTypeFetchMessage
                                                isSuccessful:YES
                                                withDetail:activityLogDetail
                                                timestamp:nil];
                [self.activityLogger addLogRecord:record];
                
                // Now handle the fetched messages.
                [self handleSuccessullyFetchedMessages:messages
                                     withFetchWaitTime:nextFetchWaitTime];
                
                if (forInitialAppLaunch) {
                    // Call checkForAppLaunchMessage immediately if app is active
                    // or next time it becomes active. We have to be on the main thread to check the application state.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                            [self checkForAppLaunchMessage];
                        } else {
                            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
                            __block id observer;
                            void(^block)(NSNotification *) = ^(NSNotification *note) {
                                [center removeObserver:observer];
                                [self checkForAppLaunchMessage];
                            };
                            observer = [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:block];
                        }
                    });
                }
            }
            // Send this regardless whether fetch is successful or not.
            [self sendFetchIsDoneNotification];
        }];
        
    } else {
        WPLogDebug(
                    @"Only %lf seconds from last fetch time. No action.",
                    intervalFromLastFetchInSeconds);
        // for no fetch case, we still send out the notification so that and display flow can continue
        // from here.
        [self sendFetchIsDoneNotification];
        WPIAMActivityRecord *record =
        [[WPIAMActivityRecord alloc] initWithActivityType:WPIAMActivityTypeCheckForFetch
                                              isSuccessful:NO
                                                withDetail:@"Abort due to check time interval "
         "not reached yet"
                                                 timestamp:nil];
        [self.activityLogger addLogRecord:record];
    }
}

- (void)checkForAppLaunchMessage {
    [self.displayExecutor checkAndDisplayNextAppLaunchMessage];
}
@end
