//
//  WPBasicApiClient.m
//  WonderPush
//
//  Created by Stéphane JAIS on 12/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPBasicApiClient.h"
#import "WPErrors.h"
#import <WonderPushCommon/WPRequestSerializer.h>
#import "WonderPush_constants.h"
#import "WPNSUtil.h"

NSString * const WPBasicApiClientResponseNotification = @"WPBasicApiClientResponseNotification";
NSString * const WPBasicApiClientResponseNotificationRequestKey = @"request";
NSString * const WPBasicApiClientResponseNotificationClientKey = @"client";
NSString * const WPBasicApiClientResponseNotificationErrorKey = @"error";

@interface WPBasicApiClient ()
@property (nonatomic, strong, nonnull) NSURLSession *URLSession;
@property (nonatomic, strong, nonnull) NSURL *baseURL;


- (void) request:(NSString*)path method:(NSString *)method params:(NSDictionary * _Nullable)params userId:(NSString * _Nullable)userId completionHandler:(void(^ _Nullable)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
@end

@implementation WPBasicApiClient

- (instancetype)initWithBaseURL:(NSURL *)baseURL clientId:(nonnull NSString *)clientId clientSecret:(nonnull NSString *)clientSecret {
    if (self = [super init]) {
        _disabled = NO;
        _baseURL = baseURL;
        _clientSecret = clientSecret;
        // We don't need cache, persistence, etc.
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSMutableDictionary *headers = [configuration.HTTPAdditionalHeaders mutableCopy] ?: [NSMutableDictionary new];
        headers[@"User-Agent"] = [WPRequestSerializer userAgentWithClientId:clientId];
        configuration.HTTPAdditionalHeaders = [NSDictionary dictionaryWithDictionary:headers];
        _URLSession = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (void)executeRequest:(WPRequest *)request {
    [self request:request.resource method:request.method ?: @"POST" params:request.params userId:request.userId completionHandler:^(NSData *data, NSURLResponse *URLResponse, NSError *error) {
        WPResponse *response = [WPResponse new];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        response.object = json;
        if (request.handler) {
            request.handler(response, error);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{
                WPBasicApiClientResponseNotificationClientKey : self,
                WPBasicApiClientResponseNotificationRequestKey : request,
            }];
            if (error) userInfo[WPBasicApiClientResponseNotificationErrorKey] = error;
            
            [NSNotificationCenter.defaultCenter postNotificationName:WPBasicApiClientResponseNotification object:response userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
        });
    }];
}

- (void) request:(NSString *)path method:(NSString *)method params:(NSDictionary *)params userId:(NSString * _Nullable)userId completionHandler:(void (^ _Nullable)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    if (self.disabled) {
        if (completionHandler) completionHandler(nil, nil, [NSError errorWithDomain:WPErrorDomain code:WPErrorClientDisabled userInfo:@{NSLocalizedDescriptionKey: @"Measurements API calls disabled"}]);
        return;
    }
    
    id bodyParam = params[@"body"];

    // Serialize bodyParam as JSON
    NSError *error = nil;
    NSData *bodyParamData = bodyParam ? [NSJSONSerialization dataWithJSONObject:bodyParam options:0 error:&error] : nil;
    if (error) {
        if (completionHandler) completionHandler(nil, nil, error);
        return;
    }
    
    // Build the request body
    NSString * _Nullable requestBodyString = bodyParamData ? [NSString stringWithFormat:@"body=%@", [[[NSString alloc] initWithData:bodyParamData encoding:NSUTF8StringEncoding] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]] : @"";
    
    // Other params
    for (NSString *param in self.additionalAllowedParams) {
        NSString *value = [WPNSUtil stringForKey:param inDictionary:params];
        if (value) {
            requestBodyString = [requestBodyString stringByAppendingFormat:@"&%@=%@", [param stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet],  [value stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
        }
    }
    
    // Let subclasses decorate
    requestBodyString = [self decorateRequestBody:requestBodyString userId:userId];

    // Resource is computed from the path by removing any leading slash
    NSString *resource = [path hasPrefix:@"/"] ? [path substringFromIndex:1] : path;
    NSURL *URL = [NSURL URLWithString:resource relativeToURL:self.baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = method;
    if (requestBodyString && requestBodyString.length) {
        request.HTTPBody = [requestBodyString dataUsingEncoding:NSUTF8StringEncoding];
    }
    // Add the authorization header after JSON serialization
    NSString *authorizationHeader = [WPRequestSerializer wonderPushAuthorizationHeaderValueForRequest:request clientSecret:self.clientSecret];
    if (authorizationHeader) {
        [request addValue:authorizationHeader forHTTPHeaderField:@"X-WonderPush-Authorization"];
    }
    NSURLSessionDataTask *task = [self.URLSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completionHandler) completionHandler(data, response, error);
    }];
    [task resume];
}

- (NSString *)decorateRequestBody:(NSString *)body userId:(NSString *)userId {
    return body;
}

- (NSArray<NSString *> *)additionalAllowedParams {
    return @[ @"accessToken", @"clientId" ];
}

@end
