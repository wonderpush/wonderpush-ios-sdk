//
//  WPLiveActivityAPIClient.m
//  WonderPush
//
//  Created by Stéphane JAIS on 12/07/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPLiveActivityAPIClient.h"
#import <WonderPushCommon/WPLog.h>
#import "WPConfiguration.h"
#import <WonderPushCommon/WPRequestSerializer.h>
#import "WPRequestVault.h"
#import "WonderPush_constants.h"
#import "WonderPush_private.h"
#import "WPRateLimiter.h"

@implementation WPLiveActivityAPIClient

+ (WPLiveActivityAPIClient *)sharedClient
{
    static WPLiveActivityAPIClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *baseURL = [WPConfiguration sharedConfiguration].baseURL;
        WPLogDebug(@"WonderPush base URL: %@", baseURL);
        sharedClient = [[WPLiveActivityAPIClient alloc] initWithBaseURL:baseURL];
    });
    return sharedClient;
}

- (NSDictionary *)decorateRequestParams:(WPRequest *)request {
    NSMutableDictionary *mutable = [super decorateRequestParams:request].mutableCopy;
    mutable[@"clientId"] = WPConfiguration.sharedConfiguration.clientId;
    mutable[@"clientSecret"] = WPConfiguration.sharedConfiguration.clientSecret;
    mutable[@"deviceId"] = WPConfiguration.sharedConfiguration.deviceId;
    mutable[@"devicePlatform"] = @"iOS";
    mutable[@"userId"] = WPConfiguration.sharedConfiguration.userId ?: @"";
    return [NSDictionary dictionaryWithDictionary:mutable];
}
@end
