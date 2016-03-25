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
#import <AFNetworking/AFNetworking.h>
#import "WPUtil.h"
#import "WPClient.h"
#import "WPConfiguration.h"
#import "WPRequestVault.h"
#import "WonderPush_private.h"
#import "WPLog.h"
#import "WPJsonUtil.h"


#pragma mark - WPJSONRequestOperation

static NSMutableArray *tokenFetchedHandlers;
static NSArray *allowedMethods = nil;


@interface WPRequestSerializer : AFHTTPRequestSerializer

+ (NSString *) wonderPushAuthorizationHeaderValueForRequest:(NSURLRequest *)request;

@end

@implementation WPRequestSerializer

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
    NSData *dBody = nil;
    NSDictionary *postParams = nil;
    if ([@"application/x-www-form-urlencoded" isEqualToString:[request valueForHTTPHeaderField:@"Content-Type"]]) {
        postParams = [WPUtil dictionaryWithFormEncodedString:[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
    } else {
        postParams = @{};
        dBody = request.HTTPBody;
    }

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

    // Add body if Content-Type is not application/x-www-form-urlencoded
    [buffer appendString:@"&"];
    //WPLog(@"%@", buffer);
    // body will be hmac-ed directly after buffer

    // Sign the buffer with the client secret using HMacSha1
    const char *cKey  = [[WPConfiguration sharedConfiguration].clientSecret cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [buffer cStringUsingEncoding:NSASCIIStringEncoding];
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmacContext hmacCtx;
    CCHmacInit(&hmacCtx, kCCHmacAlgSHA1, cKey, strlen(cKey));
    CCHmacUpdate(&hmacCtx, cData, strlen(cData));
    if (dBody) {
        //WPLog(@"%@", [[NSString alloc] initWithData:dBody encoding:NSUTF8StringEncoding]);
        CCHmacUpdate(&hmacCtx, dBody.bytes, dBody.length);
    }
    CCHmacFinal(&hmacCtx, cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString *hash = [WPUtil base64forData:HMAC];

    return [NSString stringWithFormat:@"WonderPush sig=\"%@\", meth=\"0\"", [WPUtil percentEncodedString:hash]];
}

- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request withParameters:(id)parameters error:(NSError *__autoreleasing  _Nullable *)error
{
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSMutableDictionary *mutableParameters = [parameters mutableCopy];
    for (NSString *key in parameters) {
        id value = parameters[key];
        if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
            NSError *err;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value options:0 error:&err];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            mutableParameters[key] = jsonString;
        }
    }

    request = [super requestBySerializingRequest:request withParameters:mutableParameters error:error];
    mutableRequest = [request mutableCopy];

    // Add the authorization header after JSON serialization
    NSString *authorizationHeader = [[self class] wonderPushAuthorizationHeaderValueForRequest:request];
    if (authorizationHeader) {
        [mutableRequest addValue:authorizationHeader forHTTPHeaderField:@"X-WonderPush-Authorization"];
    }

    return mutableRequest;
}

@end


#pragma mark - HandlerPair

@interface HandlerPair : NSObject

@property (copy) void (^success)(NSURLSessionTask *, id);
@property (copy) void (^error)(NSURLSessionTask *, NSError *);

@end

@implementation HandlerPair

@end


#pragma mark - WPHttpClient

@interface WPHTTPClient : AFHTTPSessionManager

@end

@implementation WPHTTPClient

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }

    self.requestSerializer = [WPRequestSerializer new];

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

/// The wrapped AFNetworking HTTP client
@property (strong, nonatomic) WPHTTPClient *jsonHttpClient;

/// The request vault
@property (strong, nonatomic) WPRequestVault *requestVault;

- (void) checkMethod:(WPRequest *)request;

@end

@implementation WPClient

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Initialize some constants
        allowedMethods = @[@"GET", @"POST", @"PUT", @"PATCH", @"DELETE"];
    });
}

+ (WPClient *)sharedClient
{
    static WPClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *baseURL = [WPConfiguration sharedConfiguration].baseURL;
        WPLog(@"WonderPush base URL: %@", baseURL);
        sharedClient = [[WPClient alloc] initWithBaseURL:baseURL];
    });
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if (self = [super init]) {
        self.isFetchingAccessToken = false;
        tokenFetchedHandlers = [[NSMutableArray alloc] init];

        WPRequestVault *wpRequestVault = [[WPRequestVault alloc] initWithClient:self];
        self.requestVault = wpRequestVault;
        self.jsonHttpClient = [[WPHTTPClient alloc] initWithBaseURL:url];
        self.jsonHttpClient.reachabilityManager = [AFNetworkReachabilityManager managerForDomain:PRODUCTION_API_DOMAIN];
        [self.jsonHttpClient.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            if (status == AFNetworkReachabilityStatusNotReachable || status == AFNetworkReachabilityStatusUnknown) {
                [WonderPush setIsReachable:NO];
            } else {
                [WonderPush setIsReachable:YES];
            }
            if (wpRequestVault) {
                [wpRequestVault reachabilityChanged:status];
            }
        }];
        [self.jsonHttpClient.reachabilityManager startMonitoring];
    }
    return self;
}


#pragma mark HTTP Access

- (AFHTTPSessionManager *)afManager
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

- (BOOL)fetchAnonymousAccessTokenIfNeededAndCall:(void (^)(NSURLSessionTask *task, id responseObject))success failure:(void (^)(NSURLSessionTask *task, NSError *error))failure
{
    if (![WPConfiguration sharedConfiguration].accessToken) {
        [self fetchAnonymousAccessTokenAndCall:success failure:failure nbRetry:0];
        return YES;
    }
    return NO;
}

- (void) fetchAnonymousAccessTokenAndCall:(void (^)(NSURLSessionTask *task, id responseObject))handler failure:(void (^)(NSURLSessionTask *task, NSError *error))failure nbRetry:(NSInteger) nbRetry {
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

    [self.jsonHttpClient POST:resource parameters:params progress:nil success:^(NSURLSessionTask *task, id response) {
        // Success

        NSDictionary *responseJson = (NSDictionary *)response;
        NSString *accessToken = [responseJson valueForKeyPath:@"token"];
        NSString *sid = [responseJson valueForKeyPath:@"data.sid"];

        // Do we have an accessToken and an SID ?
        if (sid && accessToken && sid.length && accessToken.length) {
            WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
            configuration.accessToken = accessToken;
            configuration.sid = sid;
            configuration.installationId = [responseJson valueForKeyPath:@"data.installationId"];

            id rawInstallation = [responseJson valueForKey:@"_installation"];
            if ([rawInstallation isKindOfClass:[NSDictionary class]]) {
                NSDictionary *installation = (NSDictionary *)rawInstallation;
                id installationRawUpdateDate = [installation valueForKey:@"updateDate"];
                NSDate *installationUpdateDate = [[NSDate alloc] initWithTimeIntervalSince1970:([installationRawUpdateDate isKindOfClass:[NSNumber class]] ? [(NSNumber *)installationRawUpdateDate longValue] : 0.) / 1000. ];
                id rawCustom = [installation valueForKey:@"custom"];
                NSDictionary * custom        = [rawCustom isKindOfClass:[NSDictionary class]] ? (NSDictionary *)rawCustom : @{};
                NSDictionary * customUpdated = [custom copy];
                WPConfiguration *conf = [WPConfiguration sharedConfiguration];
                NSDictionary *updated = conf.cachedInstallationCustomPropertiesUpdated ?: @{};
                NSDictionary *written = conf.cachedInstallationCustomPropertiesWritten ?: @{};
                NSDate *updatedDate = conf.cachedInstallationCustomPropertiesUpdatedDate ?: [[NSDate alloc] initWithTimeIntervalSince1970:0];
                NSDate *writtenDate = conf.cachedInstallationCustomPropertiesWrittenDate ?: [[NSDate alloc] initWithTimeIntervalSince1970:0];
                NSDictionary * diff = [WPJsonUtil diff:written with:updated];
                [WPJsonUtil merge:customUpdated with:diff];
                conf.cachedInstallationCustomPropertiesUpdated = customUpdated;
                conf.cachedInstallationCustomPropertiesWritten = custom;
                conf.cachedInstallationCustomPropertiesUpdatedDate = [updatedDate timeIntervalSinceReferenceDate] >= [installationUpdateDate timeIntervalSinceReferenceDate] ? updatedDate : installationUpdateDate;
                conf.cachedInstallationCustomPropertiesWrittenDate = [writtenDate timeIntervalSinceReferenceDate] >= [installationUpdateDate timeIntervalSinceReferenceDate] ? writtenDate : installationUpdateDate;
            }

            self.isFetchingAccessToken = NO;
            NSDictionary *userInfo = @{WP_NOTIFICATION_USER_LOGED_IN_SID_KEY: sid,
                                       WP_NOTIFICATION_USER_LOGED_IN_ACCESS_TOKEN_KEY:accessToken};

            [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_USER_LOGED_IN
                                                                object:self
                                                              userInfo:userInfo];

            [WonderPush updateInstallationCoreProperties];

            if (nil != handler) {
                handler(task, response);
            }
            @synchronized(tokenFetchedHandlers) {
                for (HandlerPair *pair in tokenFetchedHandlers) {
                    if (nil != pair.success)
                        pair.success(task, response);
                }
                [tokenFetchedHandlers removeAllObjects];
            }
        }

    } failure:^(NSURLSessionTask *task, NSError *error) {
        // Error
        WPLog(@"Could not fetch access token: %@", error);
        id jsonError = nil;
        NSData *errorBody = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        if ([errorBody isKindOfClass:[NSData class]]) {
            WPLog(@"Error body: %@", [[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding]);
        }
        if ([errorBody isKindOfClass:[NSData class]]) {
            NSError *decodeError = nil;
            jsonError = [NSJSONSerialization JSONObjectWithData:errorBody options:kNilOptions error:&decodeError];
            if (decodeError) NSLog(@"WPClient: Error while deserializing: %@", decodeError);
        }

        BOOL abort = NO;
        NSError *wpError = [WPUtil errorFromJSON:jsonError];
        if (wpError) {
            // Handle invalid credentials
            if (wpError.code == WPErrorInvalidCredentials) {
                WPLog(@"Invalid client credentials: %@", jsonError);
                NSLog(@"Please check your WonderPush clientId and clientSecret!");
                abort = YES;
            }
        }

        if (abort || nbRetry <= 0) {
            self.isFetchingAccessToken = NO;
            if (failure) {
                failure(task, error);
            }
            @synchronized(tokenFetchedHandlers) {
                for (HandlerPair *pair in tokenFetchedHandlers) {
                    if (nil != pair.error)
                        pair.error(task, error);
                }
                [tokenFetchedHandlers removeAllObjects];
            }
            return;
        }

        // Retry later
        double delayInSeconds = RETRY_INTERVAL;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.isFetchingAccessToken = NO;
            [self fetchAnonymousAccessTokenAndCall:handler failure:failure nbRetry:nbRetry - 1];
        });
    }];

}

- (void) fetchAnonymousAccessTokenAndRunRequest:(WPRequest *)request
{

    [self fetchAnonymousAccessTokenAndCall:^(NSURLSessionTask *task, id response) {
         [self requestAuthenticated:request];
    } failure:^(NSURLSessionTask *task, NSError *error) {
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
    NSTimeInterval timeRequestStart = [[NSProcessInfo processInfo] systemUptime];
    void(^success)(NSURLSessionTask *, id) = ^(NSURLSessionTask *task, id response) {
        NSTimeInterval timeRequestStop = [[NSProcessInfo processInfo] systemUptime];
        if ([response isKindOfClass:[NSDictionary class]]) {
            NSDictionary *responseJSON = (NSDictionary *)response;

            NSError *jsonError = [WPUtil errorFromJSON:responseJSON];
            if (jsonError) {
                if (request.handler)
                    request.handler(nil, jsonError);

            } else {

                WPResponse *response = [[WPResponse alloc] init];
                response.object = responseJSON;
                NSNumber *_serverTime = [(responseJSON) objectForKey:@"_serverTime"];
                NSNumber *_serverTook = [(responseJSON) objectForKey:@"_serverTook"];

                if (_serverTime != nil) {
                    NSTimeInterval serverTime = [_serverTime doubleValue] / 1000.;
                    NSTimeInterval serverTook = 0;
                    if (_serverTook)
                        serverTook = [_serverTook doubleValue] / 1000.;
                    NSTimeInterval uncertainty = (timeRequestStop - timeRequestStart - serverTook) / 2;
                    NSTimeInterval offset = (serverTime + serverTook/2.) - (timeRequestStart + timeRequestStop)/2.;
                    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

                    if (
                        // Case 1: Lower uncertainty
                        configuration.timeOffsetPrecision == 0 || uncertainty < configuration.timeOffsetPrecision
                        // Case 2: Additional check for exceptional server-side time gaps
                        || fabs(offset - configuration.timeOffset) > uncertainty + configuration.timeOffsetPrecision
                    ) {
                        configuration.timeOffset = offset;
                        configuration.timeOffsetPrecision = uncertainty;
                    }
                }

                if (request.handler)
                    request.handler(response, nil);

            }
        }
    };

    // The failure handler
    void(^failure)(NSURLSessionTask *, NSError *) = ^(NSURLSessionTask *task, NSError *error) {
        id jsonError = nil;
        NSData *errorBody = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        if ([errorBody isKindOfClass:[NSData class]]) {
            WPLog(@"Error body: %@", [[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding]);
        }
        if ([errorBody isKindOfClass:[NSData class]]) {
            NSError *decodeError = nil;
            jsonError = [NSJSONSerialization JSONObjectWithData:errorBody options:kNilOptions error:&decodeError];
            if (decodeError) NSLog(@"WPClient: Error while deserializing: %@", decodeError);
        }

        NSError *wpError = [WPUtil errorFromJSON:jsonError];
        if (wpError) {

            // Handle invalid access token by requesting a new one.
            if (wpError.code == WPErrorInvalidAccessToken) {

                WPLog(@"Invalid access token: %@", jsonError);

                // null out the access token
                WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
                configuration.accessToken = nil;
                configuration.sid = nil;
                configuration.installationId = nil;

                // Retry later
                double delayInSeconds = RETRY_INTERVAL;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self requestAuthenticated:request];
                });

            } else if (wpError.code == WPErrorInvalidCredentials) {

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
        [self.jsonHttpClient POST:request.resource parameters:params progress:nil success:success failure:failure];
    } else if ([@"GET" isEqualToString:method]) {
        [self.jsonHttpClient GET:request.resource parameters:params progress:nil success:success failure:failure];
    } else if ([@"DELETE" isEqualToString:method]) {
        [self.jsonHttpClient DELETE:request.resource parameters:params success:success failure:failure];
    } else if ([@"PUT" isEqualToString:method]) {
        [self.jsonHttpClient PUT:request.resource parameters:params success:success failure:failure];
    } else if ([@"PATCH" isEqualToString:method]) {
        [self.jsonHttpClient PATCH:request.resource parameters:params success:success failure:failure];
    }
}

- (void) checkMethod:(WPRequest *)request
{
    NSString *method = request.method.uppercaseString;
    if (!method || ![allowedMethods containsObject:method])
        [NSException raise:@"InvalidHTTPVerb" format:@"Supported verbs are GET, POST, PUT, PATCH and DELETE."];

    return;
}

- (void) requestEventually:(WPRequest *)request
{
    [self checkMethod:request];

    [self.requestVault add:request];
}

@end
