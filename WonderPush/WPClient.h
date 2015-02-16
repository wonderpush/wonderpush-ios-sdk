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
#import "WPAFHTTPClient.h"
#import "WPRequest.h"

/**
 WPClient is an implementation of WPAFHTTPClient that handles authentication to the API.
 */
@interface WPClient : NSObject


///---------------
///@name Singleton
///---------------

/**
 The default `WPClient`, configured with the values you supplied to [WonderPush setClientId:secret:].
 */
+ (WPClient *)sharedClient;


///-----------------------------
///@name Access Token Management
///-----------------------------

- (void) fetchAnonymousAccessTokenAndCall:(void (^)(WPAFHTTPRequestOperation *operation, id responseObject))handler failure:(void (^)(WPAFHTTPRequestOperation *operation, NSError *error))failure nbRetry:(NSInteger) nbRetry;


- (BOOL)fetchAnonymousAccessTokenIfNeededAndCall:(void (^)(WPAFHTTPRequestOperation *operation, id responseObject))handler failure:(void (^)(WPAFHTTPRequestOperation *operation, NSError *error))failure;

/**
 Fetch an access token if the user isn't authenticated and none is found in the `NSUserDefaults`.
 */

- (BOOL) fetchAnonymousAccessTokenIfNeeded;

/**
 Fetches an anonymous access token and runs the given request.
 @param request The request to run once the access token is fetched.
 */

- (void) fetchAnonymousAccessTokenAndRunRequest:(WPRequest *)request;


///----------------------
/// @name REST API access
///----------------------

/**
 Performs the given request. If no accessToken can be found, requests an anonymous access token before running the given request.
 @param request The request to be run
 @exception InvalidHTTPVerb   Raised when using a verb other than GET, POST or DELETE.
 */
- (void) requestAuthenticated:(WPRequest *)request;

/**
 Performs the given request in an authenticated manner, immediately. Upon network error, save this request and try again later,
 even after application restart.

 The given request is saved in the `NSUserDefaults` and will be tried again upon application restart.

 The request's handler will be called upon success or error (other than network related) unless the application has restarted.

 @param request The request to be run
 @exception InvalidHTTPVerb   Raised when using a verb other than GET, POST or DELETE.
 */
- (void) requestEventually:(WPRequest *)request;


///------------------
/// @name HTTP client
///------------------

/**
 The WPAFHTTPClient used to perform HTTP requests.
 */
@property (strong, nonatomic) WPAFHTTPClient *httpClient;
@property (assign, atomic) BOOL isFetchingAccessToken;

@end
