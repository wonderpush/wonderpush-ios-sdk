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
#import "WPIAMFetchResponseParser.h"
#import "WPIAMMessageDefinition.h"
#import "WPIAMMsgFetcherUsingRestful.h"
#import "WPIAMSDKSettings.h"
#import "WPIAMTemporaryStorage.h"

@interface WPIAMMsgFetcherUsingRestful ()
@property(readonly, nonatomic) WPIAMServerMsgFetchStorage *fetchStorage;
@property(readonly, nonatomic) WPIAMFetchResponseParser *responseParser;
@end

@implementation WPIAMMsgFetcherUsingRestful
- (instancetype)initWithFetchStorage:(WPIAMServerMsgFetchStorage *)fetchStorage
                      responseParser:(WPIAMFetchResponseParser *)responseParser {
    if (self = [super init]) {
        _fetchStorage = fetchStorage;
        _responseParser = responseParser;
    }
    return self;
}

#pragma mark - protocol WPIAMMessageFetcher
- (void)fetchMessagesWithCompletion:(WPIAMFetchMessageCompletionHandler)completion {
    NSDictionary *fetchResponse = [[WPIAMTemporaryStorage temporaryStorage] fetchResponse];
    if (fetchResponse) {
        WPIAMFetchResponseParser *responseParser = [[WPIAMFetchResponseParser alloc] initWithTimeFetcher:[WPIAMTimerWithNSDate new]];
        NSNumber *fetchWaitTimeInSeconds;
        NSInteger discardedMsgCount;
        NSArray<WPIAMMessageDefinition *> *messages = [responseParser parseAPIResponseDictionary:fetchResponse discardedMsgCount:&discardedMsgCount fetchWaitTimeInSeconds:&fetchWaitTimeInSeconds];
        [self.fetchStorage saveResponseDictionary:fetchResponse withCompletion:^(BOOL success) {
            if (!success) WPLog(@"Failed to persist server fetch response");
        }];
        completion(messages, nil, 0, nil);
        return;
    }
    completion(@[], nil, 0, nil);

    // TODO: fetch from server, parse with [self.responseParser parseAPIResponseDictionary:discardedMsgCount:fetchWaitTimeInSeconds:] and store with [self.fetchStorage saveResponseDictionary:withCompletion:]
}
@end
