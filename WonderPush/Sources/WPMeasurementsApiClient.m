//
//  WPMeasurementsApiClient.m
//  WonderPush
//
//  Created by Stéphane JAIS on 07/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPMeasurementsApiClient.h"
#import "WonderPush_private.h"
#import "WPConfiguration.h"

@interface WPMeasurementsApiClient ()
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

- (instancetype) init {
    if (self = [super init]) {
        // We don't need cache, persistence, etc.
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.URLSession = [NSURLSession sessionWithConfiguration:configuration];
        self.baseURL = [NSURL URLWithString:MEASUREMENTS_API_URL];
    }
    return self;
}
- (void) POST:(NSString *)path bodyParam:(id)bodyParam completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    
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
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    
    // Add the bodyParam
    [requestBodyString appendFormat:@"body=%@", [[[NSString alloc] initWithData:bodyParamData encoding:NSUTF8StringEncoding] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];

    // Client ID
    if (configuration.clientId && configuration.clientId.length) {
        [requestBodyString appendFormat:@"&clientId=%@", [configuration.clientId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    
    // Device platform
    [requestBodyString appendString:@"&devicePlatform=iOS"];
    
    // User ID
    if (configuration.userId && configuration.userId.length) {
        [requestBodyString appendFormat:@"&userId=%@", [configuration.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    
    // Device ID
    if (configuration.deviceId && configuration.deviceId.length) {
        [requestBodyString appendFormat:@"&deviceId=%@", [configuration.deviceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }

    // Resource is computed from the path by removing any leading slash
    NSString *resource = [path hasPrefix:@"/"] ? [path substringFromIndex:1] : path;
    NSURL *URL = [NSURL URLWithString:resource relativeToURL:self.baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    request.HTTPMethod = method;
    request.HTTPBody = [requestBodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionDataTask *task = [self.URLSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        if (completionHandler) completionHandler(data, response, error);
    }];
    [task resume];
}
@end
