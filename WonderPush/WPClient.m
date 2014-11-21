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

#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonCrypto.h>
#import "AFJSONRequestOperation.h"
#import "WPUtil.h"
#import "WPClient.h"
#import "WPConfiguration.h"
#import "WPRequestVault.h"
#import "WonderPush_private.h"


#pragma mark - WPJSONRequestOperation

static NSMutableArray *tokenFetchedHandlers;


@interface WPJSONRequestOperation : AFJSONRequestOperation

+ (NSString *) wonderPushAuthorizationHeaderValueForRequest:(NSURLRequest *)request;

@end


@implementation WPJSONRequestOperation

+ (NSString *) wonderPushAuthorizationHeaderValueForRequest:(NSURLRequest *)request
{
    NSString *method = request.HTTPMethod.uppercaseString;

    // GET requests do not need signing
    if ([@"GET" isEqualToString:method])
        return nil;

    // Step 1: add HTTP method uppercase
    NSMutableString *buffer = [[NSMutableString alloc] initWithString:method];
    [buffer appendString:@"&"];

    // Step 2: add scheme://host/path
    [buffer appendString:[WPUtil percentEncodedString:[NSString stringWithFormat:@"%@://%@%@", request.URL.scheme, request.URL.host, request.URL.path]]];

    // Gather GET params
    NSDictionary *getParams = [WPUtil dictionaryWithFormEncodedString:request.URL.query];

    // Gather POST params
    NSDictionary *postParams = [WPUtil dictionaryWithFormEncodedString:[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];

    // Step 3: add params
    [buffer appendString:@"&"];
    NSArray *paramNames = [[[NSSet setWithArray:getParams.allKeys] setByAddingObjectsFromArray:postParams.allKeys].allObjects sortedArrayUsingSelector:@selector(compare:)];

    if (paramNames.count) {
        NSString *last = paramNames.lastObject;
        for (NSString *paramName in paramNames) {
            NSString *val = [postParams valueForKey:paramName];
            if (!val)
                val = [getParams valueForKey:paramName];

            [buffer appendString:[WPUtil percentEncodedString:[NSString stringWithFormat:@"%@=%@", [WPUtil percentEncodedString:paramName], [WPUtil percentEncodedString:val]]]];

            if (![last isEqualToString:paramName]) {
                [buffer appendString:@"%26"];
            }
        }
    }

    // TODO: add the body here when we support other content types
    // than application/x-www-form-urlencoded
    [buffer appendString:@"&"];

    // Sign the buffer with the client secret using HMacSha1
    const char *cKey  = [[WPConfiguration sharedConfiguration].clientSecret cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [buffer cStringUsingEncoding:NSASCIIStringEncoding];
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString *hash = [WPUtil base64forData:HMAC];

    return [NSString stringWithFormat:@"WonderPush sig=\"%@\", meth=\"0\"", [WPUtil percentEncodedString:hash]];
}


- (id) initWithRequest:(NSURLRequest *)urlRequest
{
    // Make sure the request is mutable
    if (![urlRequest isKindOfClass:[NSMutableURLRequest class]])
        [NSException raise:@"Immutable NSURLRequest." format:NSLocalizedString(@"Url requests from AFNetworking should be mutable, please check that the AFNetworking version you are using is compatible with WonderPush.", nil)];
    NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)urlRequest;

    // Add the authorization header
    NSString *authorizationHeader = [[self class] wonderPushAuthorizationHeaderValueForRequest:mutableRequest];
    if (authorizationHeader)
        [mutableRequest addValue:authorizationHeader forHTTPHeaderField:@"X-WonderPush-Authorization"];

    return [super initWithRequest:mutableRequest];

}

@end


#pragma mark - HandlerPair

@interface HandlerPair : NSObject

@property (copy) void (^success)(AFHTTPRequestOperation *, id);
@property (copy) void (^error)(AFHTTPRequestOperation *, NSError *);

@end

@implementation HandlerPair

@end


#pragma mark - WPHttpClient

@interface WPHTTPClient : AFHTTPClient

@end

@implementation WPHTTPClient

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }

    [self registerHTTPOperationClass:[WPJSONRequestOperation class]];

    // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
	[self setDefaultHeader:@"Accept" value:@"application/json"];

    return self;
}

@end


#pragma mark - WPClient

@interface WPClient ()

/**
 The designated initializer
 @param url The base URL for this client
 */
- (id) initWithBaseURL:(NSURL *)url;

/// The AFHTTPClient
@property (strong, nonatomic) WPHTTPClient *jsonHttpClient;

/// The request vault
@property (strong, nonatomic) WPRequestVault *requestVault;

- (void) checkMethod:(WPRequest *)request;

@end

@implementation WPClient

+ (WPClient *)sharedClient
{
    static WPClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *baseURL = [WPConfiguration sharedConfiguration].baseURL;
        WPLog(@"WonderPush base URL: %@", baseURL);
        sharedClient = [[WPClient alloc] initWithBaseURL:baseURL];
        sharedClient.requestVault = [[WPRequestVault alloc] initWithClient:sharedClient];
    });
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if (self = [super init]) {
        self.jsonHttpClient = [[WPHTTPClient alloc] initWithBaseURL:url];
        [self.jsonHttpClient setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            if (status == AFNetworkReachabilityStatusNotReachable || status == AFNetworkReachabilityStatusUnknown) {
                [WonderPush setIsReachable:NO];
            } else {
                [WonderPush setIsReachable:YES];
            }

        }];
        self.isFetchingAccessToken = false;
        tokenFetchedHandlers = [[NSMutableArray alloc] init];
    }
    return self;
}


#pragma mark HTTP Access

- (AFHTTPClient *)httpClient
{
    return self.jsonHttpClient;
}


#pragma mark - Access Token

- (BOOL)fetchAnonymousAccessTokenIfNeeded {
    if (![WPConfiguration sharedConfiguration].accessToken) {
        [self fetchAnonymousAccessTokenAndCall:nil failure:nil nbRetry:0];
        return YES;
    }
    return NO;
}

- (BOOL)fetchAnonymousAccessTokenIfNeededAndCall:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    if (![WPConfiguration sharedConfiguration].accessToken) {
        [self fetchAnonymousAccessTokenAndCall:success failure:failure nbRetry:0];
        return YES;
    }
    return NO;
}

- (void) fetchAnonymousAccessTokenAndCall:(void (^)(AFHTTPRequestOperation *operation, id responseObject))handler failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure nbRetry:(NSInteger) nbRetry {
    if (YES == self.isFetchingAccessToken) {
        HandlerPair *pair = [[HandlerPair alloc] init];
        pair.success = handler;
        pair.error = failure;
        @synchronized(tokenFetchedHandlers) {
            [tokenFetchedHandlers addObject:pair];
        }
        return;
    }
    self.isFetchingAccessToken = YES;
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{@"clientId":        configuration.clientId,
                                                                                    @"devicePlatform":  @"iOS",
                                                                                    @"deviceModel":     [WPUtil deviceModel],
                                                                                    @"deviceId":        [WPUtil deviceIdentifier]}];
    if ([configuration userId] != nil) {
        [params setValue:[configuration userId] forKeyPath:@"userId"];
    }

    NSString *resource = @"authentication/accessToken";

    WPLog(@"Fetching access token");

    [self.jsonHttpClient postPath:resource parameters:params success:^(AFHTTPRequestOperation *operation, id response) {
        // Success

        WPJSONRequestOperation *jsonOperation = (WPJSONRequestOperation *)operation;
        id responseJson = jsonOperation.responseJSON;
        NSString *accessToken = [responseJson valueForKeyPath:@"token"];
        NSString *sid = [responseJson valueForKeyPath:@"data.sid"];

        // Do we have an accessToken and an SID ?
        if (sid && accessToken && sid.length && accessToken.length) {
            WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
            configuration.accessToken = accessToken;
            configuration.sid = sid;
            configuration.installationId = [responseJson valueForKeyPath:@"data.installationId"];

            self.isFetchingAccessToken = NO;
            NSDictionary *userInfo = @{WP_NOTIFICATION_USER_LOGED_IN_SID_KEY: sid,
                                       WP_NOTIFICATION_USER_LOGED_IN_ACCESS_TOKEN_KEY:accessToken};

            [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_USER_LOGED_IN
                                                                object:self
                                                              userInfo:userInfo];

            [WonderPush updateInstallationCoreProperties];

            if (nil != handler) {
                handler(operation,response);
            }
            @synchronized(tokenFetchedHandlers) {
                for (HandlerPair *pair in tokenFetchedHandlers) {
                    if (nil != pair.success)
                        pair.success(operation, response);
                }
                [tokenFetchedHandlers removeAllObjects];
            }
        }

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        // Error
        WPLog(@"Could not fetch access token: %@", error);
        if (nbRetry <= 0) {
            self.isFetchingAccessToken = NO;
            if (nil != failure) {
                id json = ((WPJSONRequestOperation *) operation).responseJSON;
                NSError *jsonError = [WPUtil errorFromJSON:json];
                if (jsonError) {
                    // Handle invalid credentials
                    if (jsonError.code == WPErrorInvalidCredentials) {
                        WPLog(@"Invalid client credentials: %@", jsonError);
                        NSLog(@"Please check your WonderPush clientId and clientSecret!");
                    }
                }
                failure(operation, error);
            }
            @synchronized(tokenFetchedHandlers) {
                for (HandlerPair *pair in tokenFetchedHandlers) {
                    if (nil != pair.error)
                        pair.error(operation, error);
                }
                [tokenFetchedHandlers removeAllObjects];
            }
            return ;
        }
        // Retry in 60 seconds
        double delayInSeconds = RETRY_INTERVAL;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.isFetchingAccessToken = NO;
            if (nbRetry > 0) {
                [self fetchAnonymousAccessTokenAndCall:handler failure:failure nbRetry:nbRetry - 1];
            }
        });
    }];

}

- (void) fetchAnonymousAccessTokenAndRunRequest:(WPRequest *)request
{

    [self fetchAnonymousAccessTokenAndCall:^(AFHTTPRequestOperation *operation, id response) {
         [self requestAuthenticated:request];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (request.handler) {
             request.handler(nil, error);
        }
    } nbRetry:0];
}


#pragma mark - REST API Access

- (void)requestAuthenticated:(WPRequest *)request
{
    // Do not fetch nil requests
    if (!request)
        return;

    // Fetch access token if needed then run request
    if (![WPConfiguration sharedConfiguration].accessToken) {
        [self fetchAnonymousAccessTokenAndRunRequest:request];
        return;
    } else {
        WPLog(@"accessToken: %@", [WPConfiguration sharedConfiguration].accessToken);
    }

    // We have an access token

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:request.params];
    [params setObject:[WPConfiguration sharedConfiguration].accessToken forKey:@"accessToken"];
    // The success handler
    NSTimeInterval timeRequestStart = [[NSDate date] timeIntervalSince1970];
    void(^success)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id response) {
        if ([operation isKindOfClass:[WPJSONRequestOperation class]]) {
            WPJSONRequestOperation *jsonOperation = (WPJSONRequestOperation *)operation;

            NSError *jsonError = [WPUtil errorFromJSON:jsonOperation.responseJSON];
            if (jsonError) {
                if (request.handler)
                    request.handler(nil, jsonError);

            } else {

                NSTimeInterval requestTime = [[NSDate date] timeIntervalSince1970] - timeRequestStart;
                WPResponse *response = [[WPResponse alloc] init];
                response.object = jsonOperation.responseJSON;
                NSNumber *serverTimeStamp = [((NSDictionary *)jsonOperation.responseJSON) objectForKey:@"_serverTime"];
                WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

                if (serverTimeStamp != nil && (configuration.timeOffsetPrecision == 0 || requestTime < configuration.timeOffsetPrecision)) {
                    NSTimeInterval systemUptime = floor([[NSProcessInfo processInfo] systemUptime]);
                    configuration.timeOffset = [serverTimeStamp floatValue] - systemUptime;
                    configuration.timeOffsetPrecision = requestTime;
                }
                if (request.handler)
                    request.handler(response, nil);
            }
        }
    };

    // The failure handler

    void(^failure)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        id json = ((WPJSONRequestOperation *) operation).responseJSON;
        NSError *jsonError = [WPUtil errorFromJSON:json];
        if (jsonError) {

            // Handle invalid access token by requesting a new one.
            if (jsonError.code == WPErrorInvalidAccessToken) {

                WPLog(@"Invalid access token: %@", jsonError);

                // null out the access token
                WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
                configuration.accessToken = nil;
                configuration.sid = nil;
                configuration.installationId = nil;

                // Retry in 60 secs
                double delayInSeconds = RETRY_INTERVAL;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self requestAuthenticated:request];
                });

            } else if (jsonError.code == WPErrorInvalidCredentials) {

                WPLog(@"Invalid client credentials: %@", jsonError);
                NSLog(@"Please check your WonderPush clientId and clientSecret!");

            } else if (request.handler) {
                request.handler(nil, jsonError);
            }

        } else if (request.handler) {
            request.handler(nil, error);
        }
    };

    // Run the request

    NSString *method = request.method.uppercaseString;

    [self checkMethod:request];

    WPLog(@"Performing request: %@", request);

    if ([@"POST" isEqualToString:method]) {
        [self.jsonHttpClient postPath:request.resource parameters:params success:success failure:failure];
    } else if ([@"GET" isEqualToString:method]) {
        [self.jsonHttpClient getPath:request.resource parameters:params success:success failure:failure];
    } else if ([@"DELETE" isEqualToString:method]) {
        [self.jsonHttpClient deletePath:request.resource parameters:params success:success failure:failure];
    } else if ([@"PUT" isEqualToString:method]) {
        [self.jsonHttpClient putPath:request.resource parameters:params success:success failure:failure];
    }
}

- (void) checkMethod:(WPRequest *)request
{
    static NSArray *allowedMethods = nil;
    if (!allowedMethods)
        allowedMethods = @[@"GET", @"POST", @"DELETE"];

    NSString *method = request.method.uppercaseString;
    if (!method || ![allowedMethods containsObject:method])
        [NSException raise:@"InvalidHTTPVerb" format:@"Supported verbs are GET, POST, DELETE."];

    return;
}

- (void) requestEventually:(WPRequest *)request
{
    [self checkMethod:request];

    [self.requestVault add:request];
}

@end
