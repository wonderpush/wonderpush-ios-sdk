//
//  WPMeasurementsApiClient.m
//  WonderPush
//
//  Created by Stéphane JAIS on 07/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPMeasurementsApiClient.h"
#import "WPRequestSerializer.h"

@interface WPMeasurementsApiClient ()
@property (nonatomic, strong, nonnull) NSString *clientSecret;
@property (nonatomic, strong, nonnull) NSString *clientId;
@property (nonatomic, strong, nonnull) NSString *deviceId;
@property (nonatomic, strong, nonnull) NSURLSession *URLSession;
@property (nonatomic, strong, nonnull) NSURL *baseURL;
@end

@implementation WPMeasurementsApiClient

+ (instancetype) sharedClient {
    static WPMeasurementsApiClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [WPMeasurementsApiClient new];
    });
    return sharedClient;
}

- (instancetype) initWithClientId:(NSString *)clientId secret:(nonnull NSString *)secret deviceId:(nonnull NSString *)deviceId {
    if (self = [super init]) {
        _clientSecret = secret;
        _clientId = clientId;
        _deviceId = deviceId;
        // We don't need cache, persistence, etc.
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.URLSession = [NSURLSession sessionWithConfiguration:configuration];
        self.baseURL = [NSURL URLWithString:MEASUREMENTS_API_URL];
    }
    return self;
}
- (void) POST:(NSString *)path bodyParam:(id)bodyParam userId:(NSString * _Nullable)userId completionHandler:(void (^ _Nullable)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
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
