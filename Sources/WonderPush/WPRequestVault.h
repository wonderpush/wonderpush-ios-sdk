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

#import <Foundation/Foundation.h>
#import <WonderPushCommon/WPRequest.h>
#import "WPAPIClient.h"
#import "WPNetworkReachabilityManager.h"

#define USER_DEFAULTS_REQUEST_VAULT_QUEUE_PREFIX @"__wonderpush_request_vault_"

@interface WPRequestVault : NSObject

@property (nonatomic, weak) id<WPRequestExecutor> requestExecutor;

- (id) initWithRequestExecutor:(id<WPRequestExecutor>)requestExecutor userDefaultsKey:(NSString *)userDefaultsKey;

- (void) restoreQueue;

- (void) reachabilityChanged:(WPNetworkReachabilityStatus)status;

- (void) add:(WPRequest *)request;

- (void) reset;

@end
