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
#import "WonderPush_constants.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
@interface WPMeasurementsApiClient ()
@property (nonatomic, strong, nonnull) NSString *clientId;
@property (nonatomic, strong, nonnull) NSString *deviceId;
@end

NS_ASSUME_NONNULL_END

@implementation WPMeasurementsApiClient

- (instancetype) initWithClientId:(NSString *)clientId secret:(nonnull NSString *)secret deviceId:(nonnull NSString *)deviceId {
    if (self = [super initWithBaseURL:[NSURL URLWithString:MEASUREMENTS_API_URL] clientSecret:secret]) {
        _clientId = clientId;
        _deviceId = deviceId;
    }
    return self;
}

- (NSString *)decorateRequestBody:(NSString *)body {
    if (!body) return nil;
    NSMutableString *requestBodyString = [NSMutableString stringWithString:body];

    // Client ID
    if (self.clientId && self.clientId.length) {
        [requestBodyString appendFormat:@"&clientId=%@", [self.clientId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    
    // Device platform
    [requestBodyString appendString:@"&devicePlatform=iOS"];

    // Add the sdk version
    [requestBodyString appendFormat:@"&sdkVersion=%@",[SDK_VERSION stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];


    // Device ID
    if (self.deviceId && self.deviceId.length) {
        [requestBodyString appendFormat:@"&deviceId=%@", [self.deviceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }

    return [NSString stringWithString:requestBodyString];
}
@end
