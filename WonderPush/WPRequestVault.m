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
#import "WPLog.h"
#import <AFNetworking/AFNetworking.h>


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

- (void) addToQueue:(WPRequest *)request;

@property (readonly) NSArray *savedRequests;

@property (strong, nonatomic) NSOperationQueue *operationQueue;

@end


@implementation WPRequestVault

- (id) initWithClient:(WPAPIClient *)client
{
    if (self = [super init]) {
        self.client = client;
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.name = @"WonderPush-RequestVault";
        self.operationQueue.maxConcurrentOperationCount = 1;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializedNotification:) name:WP_NOTIFICATION_INITIALIZED object:nil];
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
        requestQueue = [requestQueue arrayByAddingObject:[NSKeyedArchiver archivedDataWithRootObject:request]];

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

        NSArray *newRequestQueue = @[];
        for (NSData *archivedRequestData in requestQueue) {
            if (![archivedRequestData isKindOfClass:[NSData class]]) continue;
            WPRequest *archivedRequest = [NSKeyedUnarchiver unarchiveObjectWithData:archivedRequestData];

            // Skip the request to forget
            if ([request.requestId isEqual:archivedRequest.requestId])
                continue;

            // Add the archivedRequestData to the new queue
            newRequestQueue = [newRequestQueue arrayByAddingObject:archivedRequestData];
        }

        // Save
        [userDefaults setObject:newRequestQueue forKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
        [userDefaults synchronize];
    }
}

+ (NSArray *) savedRequests
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSArray *requestQueue = [userDefaults objectForKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
    NSArray *result = @[];

    if ([requestQueue isKindOfClass:[NSArray class]]) {
        for (NSData *archivedRequestData in requestQueue) {
            if (![archivedRequestData isKindOfClass:[NSData class]]) continue;
            result = [result arrayByAddingObject:[NSKeyedUnarchiver unarchiveObjectWithData:archivedRequestData]];
        }
    }

    return result;
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

- (void) addToQueue:(WPRequest *)request
{
    WPLogDebug(@"Adding request to queue: %@", request);

    WPRequestVaultOperation *operation = [[WPRequestVaultOperation alloc] initWithRequest:request vault:self];
    [self.operationQueue addOperation:operation];
}


#pragma mark - Reachability

- (void) reachabilityChanged:(AFNetworkReachabilityStatus)status
{
    switch (status) {
        case AFNetworkReachabilityStatusNotReachable:
        case AFNetworkReachabilityStatusUnknown:
            WPLogDebug(@"Reachability changed to %i, stopping queue.", status);
            [self.operationQueue setSuspended:YES];
            break;

        default:
            WPLogDebug(@"Reachability changed to %i, starting queue.", status);
            [self.operationQueue setSuspended:NO];
            break;
    }

}


#pragma mark - Initialized

- (void) initializedNotification:(NSNotification *)notification
{
    WPLogDebug(@"SDK initialized, starting queue to test reachability.");
    [self.operationQueue setSuspended:NO];
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
    WPLogDebug(@"in main of request operation");
    requestCopy.handler = ^(WPResponse *response, NSError *error) {

        WPLogDebug(@"WPRequestVaultOperation complete with response:%@ error:%@", response, error);
        if ([error isKindOfClass:[NSError class]]) {
            NSData *errorBody = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            if ([errorBody isKindOfClass:[NSData class]]) {
                WPLogDebug(@"Error body: %@", [[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding]);
            }
        }

        // Handle network errors
        if ([error isKindOfClass:[NSError class]] && [NSURLErrorDomain isEqualToString:error.domain] && error.code <= NSURLErrorBadURL) {
            // Make sure to stop the queue
            if (![WonderPush isReachable]) {
                WPLogDebug(@"Declaring not reachable");
                [self.vault reachabilityChanged:AFNetworkReachabilityStatusNotReachable];
            }
            [self.vault addToQueue:self.request];

            return;
        }

        [self.vault forget:self.request];
    };

    [self.vault.client requestAuthenticated:requestCopy];

}

@end
