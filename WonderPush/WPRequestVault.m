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

- (void) reachabilityNotification:(NSNotification *)notification;

- (void) reachabilityChanged:(AFNetworkReachabilityStatus)status;

- (void) addToQueue:(WPRequest *)request;

@property (readonly) NSArray *savedRequests;

@property (strong, nonatomic) NSOperationQueue *operationQueue;

@end


@implementation WPRequestVault

- (id) initWithClient:(WPClient *)client
{
    if (self = [super init]) {
        self.client = client;
        self.operationQueue = [[NSOperationQueue alloc] init];

        // Register for reachability notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityNotification:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializedNotification:) name:WP_NOTIFICATION_INITIALIZED object:nil];
        // Set initial reachability
        [self reachabilityChanged:[WonderPush isReachable]];

        // Add saved operations to queue
        for (WPRequest *request in self.savedRequests)
            [self addToQueue:request];
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
        if (!requestQueue)
            requestQueue = @[];

        // Build a new queue by appending the given requested, archived
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
        if (!requestQueue)
            return;

        NSArray *newRequestQueue = @[];
        for (NSData *archivedRequestData in requestQueue) {
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

- (NSArray *) savedRequests
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSArray *requestQueue = [userDefaults objectForKey:USER_DEFAULTS_REQUEST_VAULT_QUEUE];
    NSArray *result = @[];

    if (!requestQueue)
        return result;

    for (NSData *archivedRequestData in requestQueue) {
        result = [result arrayByAddingObject:[NSKeyedUnarchiver unarchiveObjectWithData:archivedRequestData]];
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
    WPLog(@"Adding request to queue: %@", request);

    WPRequestVaultOperation *operation = [[WPRequestVaultOperation alloc] initWithRequest:request vault:self];
    [self.operationQueue addOperation:operation];
}


#pragma mark - Reachability

- (void) reachabilityNotification:(NSNotification *)notification
{
    NSNumber *status = [notification.userInfo valueForKey:AFNetworkingReachabilityNotificationStatusItem];
    [self reachabilityChanged:status.intValue];
}

- (void) reachabilityChanged:(AFNetworkReachabilityStatus)status
{
    switch (status) {
        case AFNetworkReachabilityStatusNotReachable:
        case AFNetworkReachabilityStatusUnknown:
            WPLog(@"Reachability changed to %i, stopping queue.", status);
            [self.operationQueue setSuspended:YES];
            break;

        default:
            WPLog(@"Reachability changed to %i, starting queue.", status);
            [self.operationQueue setSuspended:NO];
            break;
    }

}


#pragma mark - Initialized

- (void) initializedNotification:(NSNotification *) notification
{
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
    WPLog(@"in main of request operation");
    requestCopy.handler = ^(WPResponse *response, NSError *error) {

        WPLog(@"WPRequestVaultOperation complete with response:%@ error:%@", response, error);

        // Handle network errors
        if (error && [NSURLErrorDomain isEqualToString:error.domain] && error.code <= NSURLErrorBadURL) {

            [self.vault addToQueue:self.request];

            return;
        }

        [self.vault forget:self.request];

        if (self.request.handler)
            self.request.handler(response, error);
    };

    [self.vault.client requestAuthenticated:requestCopy];

}

@end
