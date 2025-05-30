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
#import "WPResponse.h"

typedef void(^WPRequestHandler)(WPResponse * _Nullable response, NSError * _Nullable error);

/**
 WPRequest is a JSON serializable representation of a request to the WonderPush API.
 It encapsulates the following aspects of an HTTP request:

 - The associated userId
 - The resource
 - The HTTP verb (GET, POST or DELETE)
 - The HTTP parameters as a dictionary
 - The handler to be invoked when the request is run.

 */
@interface WPRequest : NSObject <NSCopying>

@property (strong, nonatomic, nullable) NSString *userId;

@property (strong, nonatomic, nonnull) NSString *resource;

@property (strong, nonatomic, nullable) WPRequestHandler handler;

@property (strong, nonatomic, nonnull) NSDictionary *params;

@property (strong, nonatomic, nonnull) NSString *method;

@property (readonly, nonnull) NSString *requestId;

- (instancetype _Nullable) init;
- (instancetype _Nullable) initFromJSON:(NSDictionary * _Nullable)dict;
- (NSDictionary * _Nonnull) toJSON;

@end

@protocol WPRequestExecutor
- (void) executeRequest:(WPRequest * _Nonnull)request;
@end
