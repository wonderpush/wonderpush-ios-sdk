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

- (void) save:(WPRequest *)request;

- (void) forget:(WPRequest *)request;

- (void) addToQueue:(WPRequest *)request delay:(NSTimeInterval)delay;

- (void) addToQueue:(WPRequest *)request;

@property (readonly) NSArray *savedRequests;

@property (strong, nonatomic) NSOperationQueue *operationQueue;

- (void) updateOperationQueueStatus;

@end


@implementation WPRequestVault
- (id)initWithRequestExecutor:(id<WPRequestExecutor>)requestExecutor
{
    if (self = [super init]) {
        self.requestExecutor = requestExecutor;
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.name = @"WonderPush-RequestVault";
        self.operationQueue.maxConcurrentOperationCount = 1;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userConsentChangedNotification:) name:WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED object:nil];
        // Set initial reachability
        [self reachabilityChanged:[WonderPush isReachable]];

        // Add saved operations to queue
        for (WPRequest *request in self.savedRequests) {
            if (![request isKindOfClass:[WPRequest class]]) continue;
            [self addToQueue:request];
        }
    }
    return self;
}


#pragma mark - Persistence

- (void) save:(WPRequest *)request
{
    @synchronized(self) {
        // Save in NSUserDefaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        NSArray *requestQueue = [userDefaults objectForKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];

        // Create queue if doesn't exist
        if (![requestQueue isKindOfClass:[NSArray class]])
            requestQueue = @[];

        // Build a new queue by appending the given request, archived
        if (@available(iOS 11.0, *)) {
            NSError *error = nil;
            requestQueue = [requestQueue arrayByAddingObject:[NSKeyedArchiver archivedDataWithRootObject:request requiringSecureCoding:NO error:&error]];
            if (error) {
                NSLog(@"Error archiving: %@", error);
            }
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            requestQueue = [requestQueue arrayByAddingObject:[NSKeyedArchiver archivedDataWithRootObject:request]];
#pragma clang diagnostic pop
        }

        // Save
        [userDefaults setObject:requestQueue forKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
        [userDefaults synchronize];
    }
}

- (void) forget:(WPRequest *)request
{
    @synchronized(self) {
        // Save in NSUserDefaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        NSArray *requestQueue = [userDefaults objectForKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
        if (![requestQueue isKindOfClass:[NSArray class]])
            return;

        NSMutableArray *newRequestQueue = [NSMutableArray arrayWithCapacity:[requestQueue count]];
        for (NSData *archivedRequestData in requestQueue) {
            if (![archivedRequestData isKindOfClass:[NSData class]]) continue;
            @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                // We should use:
                //     [NSKeyedUnarchiver unarchivedObjectOfClass:WPRequest.class fromData:archivedRequestData error:&error]
                // but the WPRequest class is shared between the WonderPush and WonderPushExtension frameworks,
                // and this leads to the following warning when running the application:
                //     objc[…]: Class WPRequest is implemented in both …/WonderPushExtension.framework/WonderPushExtension (0x101601ea8) and …/WonderPush.framework/WonderPush (0x101fa9310). One of the two will be used. Which one is undefined.
                // and the following error when unarchiving:
                //     Error Domain=NSCocoaErrorDomain Code=4864 "value for key 'root' was of unexpected class 'WPRequest' (0x101601ea8) […/WonderPushExtension.framework].
                //     Allowed classes are:
                //      {(
                //         "'WPRequest' (0x101fa9310) […/WonderPush.framework]"
                //     )}" UserInfo={NSDebugDescription=…}
                WPRequest *archivedRequest = [NSKeyedUnarchiver unarchiveObjectWithData:archivedRequestData];
#pragma clang diagnostic pop

                // Skip the request to forget
                if ([request.requestId isEqual:archivedRequest.requestId])
                    continue;
            } @catch (id exception) {
                WPLog(@"[forget] Error deserializing request in queue, skipping: %@", exception);
                continue;
            }

            // Add the archivedRequestData to the new queue
            [newRequestQueue addObject:archivedRequestData];
        }

        // Save
        [userDefaults setObject:[NSArray arrayWithArray:newRequestQueue] forKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
        [userDefaults synchronize];
    }
}

+ (NSArray *) savedRequests
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSArray *requestQueue = [userDefaults objectForKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
    if (![requestQueue isKindOfClass:[NSArray class]])
        return @[];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[requestQueue count]];
    for (NSData *archivedRequestData in requestQueue) {
        if (![archivedRequestData isKindOfClass:[NSData class]]) continue;
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // We should use:
            //     [NSKeyedUnarchiver unarchivedObjectOfClass:WPRequest.class fromData:archivedRequestData error:&error]
            // but the WPRequest class is shared between the WonderPush and WonderPushExtension frameworks,
            // and this leads to the following warning when running the application:
            //     objc[…]: Class WPRequest is implemented in both …/WonderPushExtension.framework/WonderPushExtension (0x101601ea8) and …/WonderPush.framework/WonderPush (0x101fa9310). One of the two will be used. Which one is undefined.
            // and the following error when unarchiving:
            //     Error Domain=NSCocoaErrorDomain Code=4864 "value for key 'root' was of unexpected class 'WPRequest' (0x101601ea8) […/WonderPushExtension.framework].
            //     Allowed classes are:
            //      {(
            //         "'WPRequest' (0x101fa9310) […/WonderPush.framework]"
            //     )}" UserInfo={NSDebugDescription=…}
            [result addObject:[NSKeyedUnarchiver unarchiveObjectWithData:archivedRequestData]];
#pragma clang diagnostic pop
        } @catch (id exception) {
            WPLog(@"[savedRequests] Error deserializing request in queue, skipping: %@", exception);
        }
    }

    return [NSArray arrayWithArray:result];
}

- (void) reset
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
    [userDefaults synchronize];
}


#pragma mark - Operation management

- (void) add:(WPRequest *)request
{
    [self save:request];
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

        [self.vault forget:self.request];
    };

    [self.vault.requestExecutor executeRequest:requestCopy];

}

@end
