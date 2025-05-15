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
#import "WPUtil.h"
#import <WonderPushCommon/WPErrors.h>
#import <WonderPushCommon/WPNSUtil.h>
#import "WPAPIClient.h"
#import "WPConfiguration.h"
#import "WPRequestVault.h"
#import "WonderPush_private.h"
#import <WonderPushCommon/WPLog.h>
#import <WonderPushCommon/WPJsonUtil.h>
#import "WPNetworkReachabilityManager.h"
#import <WonderPushCommon/WPRequestSerializer.h>
#import "WPRemoteConfig.h"
#import "WPInstallationCoreProperties.h"

typedef void (^SuccessBlock) (NSURLSessionTask *, id);
typedef void (^FailureBlock) (NSURLSessionTask *, NSError *);

#pragma mark - WPJSONRequestOperation

static NSArray *allowedMethods = nil;
NSString * const WPOperationFailingURLResponseDataErrorKey = @"WPOperationFailingURLResponseDataErrorKey";
NSString * const WPOperationFailingURLResponseErrorKey = @"WPOperationFailingURLResponseErrorKey";
#pragma mark - HandlerPair

@interface HandlerPair : NSObject

@property (copy) void (^success)(NSURLSessionTask *, id);
@property (copy) void (^error)(NSURLSessionTask *, NSError *);

@end

@implementation HandlerPair

@end

@interface WPBaseAPIClient ()

+ (NSDictionary *)addParameterIfNotPresent:(NSString *)name value:(NSString *)value toParameters:(NSDictionary *)params;
+ (NSDictionary *)replaceParameter:(NSString *)name value:(NSString *)value toParameters:(NSDictionary *)params;

@property (strong, nonatomic) NSURL *baseURL;
@property (strong, nonatomic) WPRequestSerializer *requestSerializer;
@property (strong, nonatomic) WPNetworkReachabilityManager *reachabilityManager;

/// The wrapped AFNetworking HTTP client
@property (strong, nonatomic) NSURLSession *URLSession;

/// The request vault
@property (strong, nonatomic) WPRequestVault *requestVault;

@property (strong, nonatomic) NSObject<OS_dispatch_queue_global> *dispatchQueue;

- (void) checkMethod:(WPRequest *)request;

@end

@interface WPAPIClient ()
@property (strong, nonatomic) NSMutableArray *tokenFetchedHandlers;
@end

@implementation WPBaseAPIClient

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Initialize some constants
        allowedMethods = @[@"GET", @"POST", @"PUT", @"PATCH", @"DELETE"];
    });
}

- (id)initWithBaseURL:(NSURL *)url userDefaultsKey:(NSString *)userDefaultsKey
{
    if (self = [super init]) {
        self.dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        WPRequestVault *wpRequestVault = [[WPRequestVault alloc] initWithRequestExecutor:self userDefaultsKey:userDefaultsKey];
        self.requestVault = wpRequestVault;
        self.reachabilityManager = [WPNetworkReachabilityManager managerForDomain:PRODUCTION_API_DOMAIN];
        [self.reachabilityManager setReachabilityStatusChangeBlock:^(WPNetworkReachabilityStatus status) {
            if (wpRequestVault) {
                [wpRequestVault reachabilityChanged:status];
            }
        }];
        [self.reachabilityManager startMonitoring];
        self.baseURL = url;
        self.requestSerializer = [WPRequestSerializer new];
        // We don't need cache, persistence, etc.
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.URLSession = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
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

- (void) restoreQueue
{
    [self.requestVault restoreQueue];
}

- (NSDictionary *)decorateRequestParams:(WPRequest *)request
{
    NSDictionary *params = request.params;
    // Add the sdk version
    params = [[self class] addParameterIfNotPresent:@"sdkVersion" value:[WPInstallationCoreProperties getSDKVersionNumber] toParameters:params];
    return params;
}

- (void)executeRequest:(WPRequest *)request {
    // Do not fetch nil requests
    if (!request)
        return;

    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // Avoid being killed by saying we are done
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    }];

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:[self decorateRequestParams:request]];

    // The success handler
    NSTimeInterval timeRequestStart = NSDate.date.timeIntervalSince1970;
    void(^success)(NSURLSessionTask *, id) = ^(NSURLSessionTask *task, id response) {
        NSTimeInterval timeRequestStop = NSDate.date.timeIntervalSince1970;
        if ([response isKindOfClass:[NSDictionary class]]) {
            NSDictionary *responseJSON = (NSDictionary *)response;

            NSError *wpError = [WPUtil errorFromJSON:responseJSON];
            if (wpError) {
                if (request.handler)
                    request.handler(nil, wpError);

            } else {

                WPResponse *response = [[WPResponse alloc] init];
                response.object = responseJSON;
                NSNumber *_serverTime = [WPNSUtil numberForKey:@"_serverTime" inDictionary:responseJSON];
                NSNumber *_serverTook = [WPNSUtil numberForKey:@"_serverTook" inDictionary:responseJSON];

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

        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    };

    // The failure handler
    void(^failure)(NSURLSessionTask *, NSError *) = ^(NSURLSessionTask *task, NSError *error) {
        NSDictionary *jsonError = nil;
        NSData *errorBody = error.userInfo[WPOperationFailingURLResponseDataErrorKey];
        if ([errorBody isKindOfClass:[NSData class]]) {
            WPLogDebug(@"Error body: %@", [[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding]);
        }
        if ([errorBody isKindOfClass:[NSData class]]) {
            NSError *decodeError = nil;
            id decoded = [NSJSONSerialization JSONObjectWithData:errorBody options:kNilOptions error:&decodeError];
            if ([decoded isKindOfClass:[NSDictionary class]]) jsonError = decoded;
            if (decodeError) WPLog(@"WPAPIClient: Error while deserializing: %@", decodeError);
        }

        NSError *wpError = [WPUtil errorFromJSON:jsonError];
        if (wpError) {

            // Handle invalid access token by requesting a new one.
            if (wpError.code == WPErrorInvalidAccessToken) {

                WPLogDebug(@"Invalid access token: %@", jsonError);

                // null out the access token
                WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
                NSString *prevUserId = configuration.userId;
                [configuration changeUserId:request.userId];
                configuration.accessToken = nil;
                configuration.sid = nil;
                configuration.installationId = nil;
                [configuration changeUserId:prevUserId];

                // Retry later
                double delayInSeconds = RETRY_INTERVAL;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self executeRequest:request];
                });

            } else if (wpError.code == WPErrorInvalidCredentials) {

                WPLogDebug(@"Invalid client credentials: %@", jsonError);
                WPLog(@"Please check your WonderPush clientId and clientSecret!");

            } else if (request.handler) {
                request.handler(nil, wpError);
            }

        } else if (request.handler) {
            request.handler(nil, error);
        }

        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    };

    // Run the request

    NSString *method = request.method.uppercaseString;

    [self checkMethod:request];

    WPLogDebug(@"Performing request: %@", request);

    if ([@"POST" isEqualToString:method]) {
        [self POST:request.resource parameters:[params copy] success:success failure:failure];
    } else if ([@"GET" isEqualToString:method]) {
        [self GET:request.resource parameters:[params copy] success:success failure:failure];
    } else if ([@"DELETE" isEqualToString:method]) {
        [self DELETE:request.resource parameters:[params copy] success:success failure:failure];
    } else if ([@"PUT" isEqualToString:method]) {
        [self PUT:request.resource parameters:[params copy] success:success failure:failure];
    } else if ([@"PATCH" isEqualToString:method]) {
        [self PATCH:request.resource parameters:[params copy] success:success failure:failure];
    }
}

#pragma mark - Networking

- (void) POST:(NSString *)resource parameters:(NSDictionary *)parameters success:(SuccessBlock)successBlock failure:(FailureBlock)failureBlock
{
    [self requestWithMethod:@"POST" resource:resource parameters:parameters success:successBlock failure:failureBlock];
}

- (void) GET:(NSString *)resource parameters:(NSDictionary *)parameters success:(SuccessBlock)successBlock failure:(FailureBlock)failureBlock
{
    [self requestWithMethod:@"GET" resource:resource parameters:parameters success:successBlock failure:failureBlock];
}

- (void) DELETE:(NSString *)resource parameters:(NSDictionary *)parameters success:(SuccessBlock)successBlock failure:(FailureBlock)failureBlock
{
    [self requestWithMethod:@"DELETE" resource:resource parameters:parameters success:successBlock failure:failureBlock];
}

- (void) PUT:(NSString *)resource parameters:(NSDictionary *)parameters success:(SuccessBlock)successBlock failure:(FailureBlock)failureBlock
{
    [self requestWithMethod:@"PUT" resource:resource parameters:parameters success:successBlock failure:failureBlock];
}

- (void) PATCH:(NSString *)resource parameters:(NSDictionary *)parameters success:(SuccessBlock)successBlock failure:(FailureBlock)failureBlock
{
    [self requestWithMethod:@"PATCH" resource:resource parameters:parameters success:successBlock failure:failureBlock];
}

- (void) requestWithMethod:(NSString *)method resource:(NSString *)resource parameters:(NSDictionary *)parameters success:(SuccessBlock)successBlock failure:(FailureBlock)failureBlock
{
    if (self.disabled) {
        if (failureBlock) failureBlock(nil, [NSError errorWithDomain:WPErrorDomain code:WPErrorClientDisabled userInfo:@{NSLocalizedDescriptionKey: @"API calls disabled"}]);
        return;
    }
    SuccessBlock callSuccessBlock = ^(NSURLSessionTask *task, id result) {
        dispatch_async(self.dispatchQueue, ^{
            successBlock(task, result);
        });
    };
    FailureBlock callFailureBlock = ^(NSURLSessionTask *task, NSError *error) {
        dispatch_async(self.dispatchQueue, ^{
            failureBlock(task, error);
        });
    };
    static NSIndexSet *acceptableStatusCodes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    });
    NSURL *URL = [NSURL URLWithString:resource relativeToURL:self.baseURL];
    NSError *error = nil;
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:URL];
    mutableRequest.HTTPMethod = method;
    NSString *clientId = [WPConfiguration sharedConfiguration].clientId;
    NSString *clientSecret = [WPConfiguration sharedConfiguration].clientSecret;
    NSURLRequest *request = [self.requestSerializer
                             requestBySerializingRequest:mutableRequest
                             withParameters:parameters
                             clientId:clientId
                             clientSecret:clientSecret
                             error:&error];
    if (error) {
        callFailureBlock(nil, error);
        return;
    }
    __block NSURLSessionDataTask *task;
    void(^completion)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable) = ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            callFailureBlock(task, error);
            return;
        }
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        BOOL success = [acceptableStatusCodes containsIndex:(NSUInteger) HTTPResponse.statusCode];
        if (!success) {
            NSMutableDictionary *mutableUserInfo = [@{
                                                      NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Request failed: %@ (%ld)", [NSHTTPURLResponse localizedStringForStatusCode:HTTPResponse.statusCode], (long)HTTPResponse.statusCode],
                                                      NSURLErrorFailingURLErrorKey:[response URL],
                                                      WPOperationFailingURLResponseErrorKey: response,
                                                      } mutableCopy];
            
            if (data) {
                mutableUserInfo[WPOperationFailingURLResponseDataErrorKey] = data;
            }
            NSError *error = [NSError errorWithDomain:WPErrorDomain code:WPErrorHTTPFailure userInfo:[mutableUserInfo copy]];
            callFailureBlock(task, error);
            return;
        }
        NSError *JSONError = nil;
        id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
        if (JSONError) {
            callFailureBlock(task, JSONError);
            return;
        }
        if ([result isKindOfClass:NSDictionary.class]) {
            id configVersion = result[@"_configVersion"];
            if ([configVersion isKindOfClass:NSString.class]) {
                [WonderPush.remoteConfigManager declareVersion:configVersion];
            } else if ([configVersion isKindOfClass:NSNumber.class]) {
                [WonderPush.remoteConfigManager declareVersion:[configVersion stringValue]];
            }
        }
        callSuccessBlock(task, result);
    };
    task = [self.URLSession dataTaskWithRequest:request completionHandler:completion];
    [task resume];
}


#pragma mark - Parameters
+ (NSDictionary *)addParameterIfNotPresent:(NSString *)name value:(NSString *)value toParameters:(NSDictionary *)params
{
    if (!params[name]) {
        NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithDictionary:params];
        mutable[name] = value;
        return [NSDictionary dictionaryWithDictionary:mutable];
    }
    return params;
}

+ (NSDictionary *)replaceParameter:(NSString *)name value:(NSString *)value toParameters:(NSDictionary *)params
{
    NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithDictionary:params];
    if (name && value) {
        mutable[name] = value;
    }
    return [NSDictionary dictionaryWithDictionary:mutable];
}

@end

#pragma mark - WPAPIClient

@implementation WPAPIClient

+ (WPAPIClient *)sharedClient
{
    static WPAPIClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *baseURL = [WPConfiguration sharedConfiguration].baseURL;
        WPLogDebug(@"WonderPush base URL: %@", baseURL);
        sharedClient = [[WPAPIClient alloc] initWithBaseURL:baseURL];
    });
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if (self = [super initWithBaseURL:url userDefaultsKey:[NSString stringWithFormat:@"%@_apiclient", USER_DEFAULTS_REQUEST_VAULT_QUEUE_PREFIX]]) {
        self.isFetchingAccessToken = false;
        self.tokenFetchedHandlers = [[NSMutableArray alloc] init];
        WPRequestVault *vault = self.requestVault;
        [self.reachabilityManager setReachabilityStatusChangeBlock:^(WPNetworkReachabilityStatus status) {
            if (status == WPNetworkReachabilityStatusNotReachable || status == WPNetworkReachabilityStatusUnknown) {
                [WonderPush setIsReachable:NO];
            } else {
                [WonderPush setIsReachable:YES];
            }
            if (vault) {
                [vault reachabilityChanged:status];
            }
        }];
    }
    return self;
}

#pragma mark - WPRequestExecutor

- (void)executeRequest:(WPRequest *)request
{
    // Fetch access token if needed then run request
    NSString *accessToken = [[WPConfiguration sharedConfiguration] getAccessTokenForUserId:request.userId];
    if (!accessToken) {
        [self fetchAccessTokenAndRunRequest:request];
        return;
    } else {
        WPLogDebug(@"Using accessToken: %@", accessToken);
        [super executeRequest:request];
    }
}

#pragma mark - Access Token

- (void) fetchAccessTokenAndCall:(void (^)(NSURLSessionTask *task, id responseObject))handler failure:(void (^)(NSURLSessionTask *task, NSError *error))failure nbRetry:(NSInteger)nbRetry forUserId:(NSString *)userId
{
    
    [WonderPush.remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {

        // Refuse to get an access token for non-subscribers
        if (![WonderPush subscriptionStatusIsOptIn]
            && ![config.data[WP_REMOTE_CONFIG_ALLOW_ACCESS_TOKEN_FOR_NON_SUBSCRIBERS] boolValue]) {
            if (failure) {
                failure(nil, [NSError errorWithDomain:WPErrorDomain code:WPErrorClientDisabled userInfo:@{NSLocalizedDescriptionKey: @"Not opt-in"}]);
            }
            return;
        }

        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        NSString *clientId = configuration.clientId;
        NSString *deviceModel = [WPUtil deviceModel];
        NSString *deviceId = [WPUtil deviceIdentifier];

        if (!clientId || !deviceId || YES == self.isFetchingAccessToken) {
            HandlerPair *pair = [[HandlerPair alloc] init];
            pair.success = handler;
            pair.error = failure;
            @synchronized(self.tokenFetchedHandlers) {
                [self.tokenFetchedHandlers addObject:pair];
            }
            return;
        }
        self.isFetchingAccessToken = YES;
        [WonderPush safeDeferWithConsent:^{
            NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{@"clientId":        clientId,
                                                                                            @"devicePlatform":  @"iOS",
                                                                                            @"deviceModel":     deviceModel ?: [NSNull null],
                                                                                            @"deviceId":        deviceId}];
            if (userId != nil) {
                [params setValue:userId forKeyPath:@"userId"];
            }
            
            NSString *resource = @"authentication/accessToken";
            
            WPLogDebug(@"Fetching access token");
            WPLogDebug(@"POST %@ with params %@", resource, params);
            
            __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"WP-FetchAccessToken" expirationHandler:^{
                // Avoid being killed by saying we are done
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            }];
            
            [self POST:resource parameters:[params copy] success:^(NSURLSessionTask *task, id response) {
                // Success
                WPLogDebug(@"Got access token response: %@", response);
                
                NSDictionary *responseJson = (NSDictionary *)response;
                NSString *accessToken = [WPNSUtil stringForKey:@"token" inDictionary:responseJson];
                NSDictionary *data = [WPNSUtil dictionaryForKey:@"data" inDictionary:responseJson];
                NSString *sid = data ? [WPNSUtil stringForKey:@"sid" inDictionary:data] : nil;
                
                // Do we have an accessToken and an SID ?
                if (sid && accessToken && sid.length && accessToken.length) {
                    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
                    NSString *prevUserId = configuration.userId;
                    [configuration changeUserId:userId];
                    configuration.accessToken = accessToken;
                    configuration.sid = sid;
                    configuration.installationId = [WPNSUtil stringForKey:@"installationId" inDictionary:data];
                    
                    NSDictionary *installation = [WPNSUtil dictionaryForKey:@"_installation" inDictionary:responseJson];
                    if (installation) {
                        NSDate *installationUpdateDate = [[NSDate alloc] initWithTimeIntervalSince1970:[[WPNSUtil numberForKey:@"updateDate" inDictionary:installation] longValue] / 1000. ];
                        [WonderPush receivedFullInstallationFromServer:installation updateDate:installationUpdateDate];
                    }
                    
                    [configuration changeUserId:prevUserId];
                    
                    self.isFetchingAccessToken = NO;
                    NSDictionary *userInfo = @{WP_NOTIFICATION_USER_LOGED_IN_SID_KEY: sid,
                                               WP_NOTIFICATION_USER_LOGED_IN_ACCESS_TOKEN_KEY:accessToken};
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_USER_LOGED_IN
                                                                        object:self
                                                                      userInfo:userInfo];
                    
                    [WonderPush refreshPreferencesAndConfiguration];
                    
                    if (nil != handler) {
                        handler(task, response);
                    }
                    @synchronized(self.tokenFetchedHandlers) {
                        NSArray *handlers = [NSArray arrayWithArray:self.tokenFetchedHandlers];
                        for (HandlerPair *pair in handlers) {
                            if (nil != pair.success)
                                pair.success(task, response);
                        }
                        [self.tokenFetchedHandlers removeAllObjects];
                    }
                } else {
                    WPLog(@"Malformed access token response: %@", response);
                }
                
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                
            } failure:^(NSURLSessionTask *task, NSError *error) {
                // Error
                if ([error.domain isEqualToString:WPErrorDomain]
                    && error.code == WPErrorClientDisabled) {
    #if DEBUG
                    // Hide this error on released SDKs (it's just for us).
                    WPLogDebug(@"Could not fetch access token because client is disabled");
    #endif
                } else {
                    WPLogDebug(@"Could not fetch access token: %@", error);
                }
                id jsonError = nil;
                NSData *errorBody = error.userInfo[WPOperationFailingURLResponseDataErrorKey];
                if ([errorBody isKindOfClass:[NSData class]]) {
                    WPLogDebug(@"Error body: %@", [[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding]);
                    NSError *decodeError = nil;
                    jsonError = [NSJSONSerialization JSONObjectWithData:errorBody options:kNilOptions error:&decodeError];
                    if (decodeError) WPLog(@"WPAPIClient: Error while deserializing: %@", decodeError);
                }
                
                BOOL abort = NO;
                NSError *wpError = [WPUtil errorFromJSON:jsonError];
                if (wpError) {
                    // Handle invalid credentials
                    if (wpError.code == WPErrorInvalidCredentials) {
                        WPLogDebug(@"Invalid client credentials: %@", jsonError);
                        WPLog(@"Please check your WonderPush clientId and clientSecret!");
                        abort = YES;
                    }
                }
                
                if (abort || nbRetry <= 0) {
                    self.isFetchingAccessToken = NO;
                    if (failure) {
                        failure(task, error);
                    }
                    @synchronized(self.tokenFetchedHandlers) {
                        NSArray *handlers = [NSArray arrayWithArray:self.tokenFetchedHandlers];
                        for (HandlerPair *pair in handlers) {
                            if (nil != pair.error)
                                pair.error(task, error);
                        }
                        [self.tokenFetchedHandlers removeAllObjects];
                    }
                    abort = YES;
                }
                
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                
                if (abort) {
                    return;
                }
                
                // Retry later
                double delayInSeconds = RETRY_INTERVAL;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    self.isFetchingAccessToken = NO;
                    [self fetchAccessTokenAndCall:handler failure:failure nbRetry:nbRetry - 1 forUserId:userId];
                });
            }];
        }];
    }];
}

- (void) fetchAccessTokenAndRunRequest:(WPRequest *)request
{

    [self fetchAccessTokenAndCall:^(NSURLSessionTask *task, id response) {
         [self executeRequest:request];
    } failure:^(NSURLSessionTask *task, NSError *error) {
        if (request.handler) {
             request.handler(nil, error);
        }
    } nbRetry:0 forUserId:request.userId];
}

- (NSDictionary *)decorateRequestParams:(WPRequest *)request {
    NSMutableDictionary *mutable = [super decorateRequestParams:request].mutableCopy;
    NSString *accessToken = WPConfiguration.sharedConfiguration.accessToken;
    if (accessToken) mutable[@"accessToken"] = accessToken;
    return [NSDictionary dictionaryWithDictionary:mutable];
}
@end
