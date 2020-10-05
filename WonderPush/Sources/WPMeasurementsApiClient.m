//
//  WPMeasurementsApiClient.m
//  WonderPush
//
//  Created by Stéphane JAIS on 07/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPMeasurementsApiClient.h"
#import "WPRequestSerializer.h"
#import "WPErrors.h"
#import "WPLog.h"
#import "WPRequestVault.h"
#import "WPNetworkReachabilityManager.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
@interface WPMeasurementsApiClient ()
@property (nonatomic, strong, nonnull) NSString *clientSecret;
@property (nonatomic, strong, nonnull) NSString *clientId;
@property (nonatomic, strong, nonnull) NSString *deviceId;
@property (nonatomic, strong, nonnull) NSURLSession *URLSession;
@property (nonatomic, strong, nonnull) NSURL *baseURL;


- (void) POST:(NSString*)path bodyParam:(id)bodyParam userId:(NSString * _Nullable)userId completionHandler:(void(^ _Nullable)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END

@implementation WPMeasurementsApiClient

- (instancetype) initWithClientId:(NSString *)clientId secret:(nonnull NSString *)secret deviceId:(nonnull NSString *)deviceId {
    if (self = [super init]) {
        _clientSecret = secret;
        _clientId = clientId;
        _deviceId = deviceId;
        _disabled = NO;
        // We don't need cache, persistence, etc.
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        _URLSession = [NSURLSession sessionWithConfiguration:configuration];
        _baseURL = [NSURL URLWithString:MEASUREMENTS_API_URL];
    }
    return self;
}

- (void)executeRequest:(WPRequest *)request {
    if (![@"POST" isEqualToString:request.method]) {
        WPLogDebug(@"ERROR: management API client only supports POST requests.");
        return;
    }
    id bodyParam = [request.params objectForKey:@"body"];
    if (!bodyParam) {
        WPLogDebug(@"ERROR: management API client does not accept a nil body.");
        return;
    }
    WPLogDebug(@"Performing request with measurement API: %@", request);
    [self POST:request.resource bodyParam:bodyParam userId:request.userId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (request.handler) {
            WPResponse *response = [WPResponse new];
            id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            response.object = json;
            request.handler(response, error);
        }
    }];
}
- (void) POST:(NSString *)path bodyParam:(id)bodyParam userId:(NSString * _Nullable)userId completionHandler:(void (^ _Nullable)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    if (self.disabled) {
        if (completionHandler) completionHandler(nil, nil, [NSError errorWithDomain:WPErrorDomain code:WPErrorForbidden userInfo:@{NSLocalizedDescriptionKey: @"Measurements API calls disabled"}]);
        return;
    }
    
    NSString *method = @"POST";

    // Serialize bodyParam as JSON
    NSError *error = nil;
    NSData *bodyParamData = [NSJSONSerialization dataWithJSONObject:bodyParam options:0 error:&error];
    if (error) {
        if (completionHandler) completionHandler(nil, nil, error);
        return;
    }
    
    // Build the request body
    NSMutableString *requestBodyString = [NSMutableString new];
    
    // Add the bodyParam
    [requestBodyString appendFormat:@"body=%@", [[[NSString alloc] initWithData:bodyParamData encoding:NSUTF8StringEncoding] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];

    // Client ID
    if (self.clientId && self.clientId.length) {
        [requestBodyString appendFormat:@"&clientId=%@", [self.clientId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    
    // Device platform
    [requestBodyString appendString:@"&devicePlatform=iOS"];
    
    // User ID
    if (userId && userId.length) {
        [requestBodyString appendFormat:@"&userId=%@", [userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    
    // Device ID
    if (self.deviceId && self.deviceId.length) {
        [requestBodyString appendFormat:@"&deviceId=%@", [self.deviceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }

    // Resource is computed from the path by removing any leading slash
    NSString *resource = [path hasPrefix:@"/"] ? [path substringFromIndex:1] : path;
    NSURL *URL = [NSURL URLWithString:resource relativeToURL:self.baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = method;
    request.HTTPBody = [requestBodyString dataUsingEncoding:NSUTF8StringEncoding];
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
@end
