/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "WPRequestVault.h"
#import "WonderPush_private.h"
#import <WonderPushCommon/WPLog.h>
#import <WonderPushCommon/WPErrors.h>

#pragma mark - RequestVaultOperation

@interface WPRequestVaultOperation : NSOperation

- (id) initWithRequest:(WPRequest *)request vault:(WPRequestVault *)vault;

@property (nonatomic, strong) WPRequest *request;

@property (weak, nonatomic) WPRequestVault *vault;

@end


#pragma mark - Request vault

@interface WPRequestVault ()

- (void) saveRequest:(WPRequest *)request;

- (void) forgetRequest:(WPRequest *)request;

- (void) addToQueue:(WPRequest *)request delay:(NSTimeInterval)delay;

- (void) addToQueue:(WPRequest *)request;

@property (readonly, strong, nonatomic) NSString *userDefaultsKey;

@property (atomic) bool queueRestored;

@property (strong, nonatomic) NSOperationQueue *operationQueue;

- (void) updateOperationQueueStatus;

- (NSMutableArray<NSDictionary *> *) loadQueue;

@end


@implementation WPRequestVault
- (id)initWithRequestExecutor:(id<WPRequestExecutor>)requestExecutor userDefaultsKey:(NSString *)userDefaultsKey
{
    if (self = [super init]) {
        self.requestExecutor = requestExecutor;
        _userDefaultsKey = userDefaultsKey;
        _queueRestored = false;
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.name = [NSString stringWithFormat:@"WonderPush-RequestVault:%@", userDefaultsKey];
        self.operationQueue.maxConcurrentOperationCount = 1;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userConsentChangedNotification:) name:WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED object:nil];
        // Set initial reachability
        [self reachabilityChanged:[WonderPush isReachable]];
    }
    return self;
}

// Load initial requests. Do not call from constructor so that requestExecutor can construct this very request vault within its init method and have time to finish its initialization.
- (void) restoreQueue
{
    @synchronized(self) {
        if (_queueRestored == false) {
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults removeObjectForKey:@"__wonderpush_request_vault"]; // cleanup older name
            [userDefaults synchronize];

            // Add saved operations to queue
            NSMutableArray<NSDictionary *> *requestQueue = [self loadQueue];
            NSUInteger requestQueueInitialCount = [requestQueue count];
            [requestQueue filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                WPRequest *request = [[WPRequest alloc] initFromJSON:evaluatedObject];
                if (!request) return false;
                [self addToQueue:request];
                return true;
            }]];
            if (requestQueueInitialCount != [requestQueue count]) {
                // Some requests were not valid and got removed, save new queue
                [self saveQueue:requestQueue];
            }

            _queueRestored = true;
        }
    }
}

#pragma mark - Persistence

- (void) saveRequest:(WPRequest *)request
{
    @synchronized(self) {
        NSMutableArray<NSDictionary *> *requestQueue = [self loadQueue];
        [requestQueue addObject:[request toJSON]];
        [self saveQueue:requestQueue];
    }
}

- (void) forgetRequest:(WPRequest *)request
{
    @synchronized(self) {
        NSMutableArray<NSDictionary *> *requestQueue = [self loadQueue];
        [requestQueue filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return [evaluatedObject isKindOfClass:[NSDictionary class]] // keep objects of the right class
                && ![evaluatedObject[@"requestId"] isEqualToString:request.requestId] // keep requestIds different from the one we want to forget
            ;
        }]];
        [self saveQueue:requestQueue];
    }
}

// Returns NSDictionary not parsed into WPRequests
- (NSMutableArray<NSDictionary *> *) loadQueue
{
    @synchronized(self) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        NSMutableArray<NSDictionary *> *requestQueue = nil;

        NSData *queueJson = [userDefaults dataForKey:self.userDefaultsKey];
        if (queueJson != nil) {
            NSError *error = NULL;
            requestQueue = [NSJSONSerialization JSONObjectWithData:queueJson options:NSJSONReadingMutableContainers error:&error];
            if (error) {
                WPLogDebug(@"Error while reading request vault %@: %@", self.userDefaultsKey, error);
            }
        }

        if (![requestQueue isKindOfClass:[NSMutableArray class]]) {
            if (requestQueue != nil) {
                WPLogDebug(@"Error while reading request vault %@: unexpected value of class %@: %@", self.userDefaultsKey, [requestQueue class], requestQueue);
            }
            requestQueue = [[NSMutableArray alloc] init];
        }

        return requestQueue;
    }
}

- (void) saveQueue:(NSArray<NSDictionary *> *)requestQueue
{
    @synchronized(self) {
        // Save
        NSError *error = NULL;
        NSData *queueJson = [NSJSONSerialization dataWithJSONObject:requestQueue options:0 error:&error];
        if (error) {
            WPLogDebug(@"Error while serializing request vault %@: %@", self.userDefaultsKey, error);
            return;
        }

        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:queueJson forKey:self.userDefaultsKey];
        [userDefaults synchronize];
    }
}

- (void) reset
{
    @synchronized(self) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults removeObjectForKey:self.userDefaultsKey];
        [userDefaults synchronize];
    }
}


#pragma mark - Operation management

- (void) add:(WPRequest *)request
{
    [self restoreQueue]; // ensure queue is restored at first use, even though the creator of the current instance should have done so already
    [self saveRequest:request];
    [self addToQueue:request];
}

- (void) addToQueue:(WPRequest *)request {
    [self addToQueue:request delay:0];
}

- (void) addToQueue:(WPRequest *)request delay:(NSTimeInterval)delay
{
    WPLogDebug(@"Adding request to queue: %@ with delay: %f client: %@", request, delay, self.requestExecutor);
    void(^addToQueue)(void) = ^{
        WPRequestVaultOperation *operation = [[WPRequestVaultOperation alloc] initWithRequest:request vault:self];
        [self.operationQueue addOperation:operation];
    };
    if (delay > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addToQueue();
        });
    } else {
        addToQueue();
    }

}

- (void) updateOperationQueueStatus;
{
    BOOL suspend = !([WonderPush isReachable] && [WonderPush hasUserConsent]);
    WPLogDebug(@"%@ request vault operation queue. %@", suspend ? @"Stopping" : @"Starting", self.requestExecutor);
    [self.operationQueue setSuspended:suspend];
}

#pragma mark - Reachability

- (void) reachabilityChanged:(WPNetworkReachabilityStatus)status
{
    [self updateOperationQueueStatus];
}

#pragma mark - User consent
- (void) userConsentChangedNotification:(NSNotification *)notification
{
    [self updateOperationQueueStatus];
}

@end


#pragma mark - Request vault operation

@implementation WPRequestVaultOperation

- (id) initWithRequest:(WPRequest *)request vault:(WPRequestVault *)vault
{
    if (self = [super init]) {
        self.queuePriority = NSOperationQueuePriorityLow;
        self.request = request;
        self.vault = vault;
    }
    return self;
}

- (void) main
{
    WPRequest *requestCopy = [self.request copy];
    requestCopy.handler = ^(WPResponse *response, NSError *error) {

        // Error
        if (error
            && [error.domain isEqualToString:WPErrorDomain]
            && error.code == WPErrorClientDisabled) {
#if DEBUG
        WPLogDebug(@"WPRequestVaultOperation error because client is disabled");
#endif
        } else {
            WPLogDebug(@"WPRequestVaultOperation complete with response:%@ error:%@", response, error);
        }
        if ([error isKindOfClass:[NSError class]]) {
            NSData *errorBody = error.userInfo[WPOperationFailingURLResponseDataErrorKey];
            if ([errorBody isKindOfClass:[NSData class]]) {
                WPLogDebug(@"Error body: %@", [[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding]);
            }
        }

        BOOL handleError = NO;
        // Handle network errors
        if ([error isKindOfClass:[NSError class]] && [NSURLErrorDomain isEqualToString:error.domain] && error.code <= NSURLErrorBadURL) {
            handleError = YES;
        }
        // Handle cliend disabled errors (they occur when the APIClient and MeasurementsApiClient are disabled)
        if ([error isKindOfClass:NSError.class] && [WPErrorDomain isEqualToString:error.domain] && error.code == WPErrorClientDisabled) {
            handleError = YES;
        }
        if (handleError) {
            // Make sure to stop the queue
            if (![WonderPush isReachable]) {
                WPLogDebug(@"Declaring not reachable");
                [self.vault reachabilityChanged:WPNetworkReachabilityStatusNotReachable];
            }
            [self.vault addToQueue:self.request delay:10];

            return;
        }

        [self.vault forgetRequest:self.request];
    };

    [self.vault.requestExecutor executeRequest:requestCopy];

}

@end
