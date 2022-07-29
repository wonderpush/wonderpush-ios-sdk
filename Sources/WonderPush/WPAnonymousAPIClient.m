//
//  WPAnonymousAPIClient.m
//  WonderPush
//
//  Created by Stéphane JAIS on 12/07/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPAnonymousAPIClient.h"
#import "WPLog.h"
#import "WPConfiguration.h"
#import "WPRequestSerializer.h"
#import "WPRequestVault.h"
#import "WonderPush_constants.h"
#import "WonderPush_private.h"
#import "WPRateLimiter.h"

@implementation WPAnonymousAPIClient

+ (WPAnonymousAPIClient *)sharedClient
{
    static WPAnonymousAPIClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *baseURL = [WPConfiguration sharedConfiguration].baseURL;
        WPLogDebug(@"WonderPush base URL: %@", baseURL);
        sharedClient = [[WPAnonymousAPIClient alloc] initWithBaseURL:baseURL];
    });
    return sharedClient;
}

- (void)executeRequest:(WPRequest *)request {
    [WonderPush.remoteConfigManager read:^(WPRemoteConfig *remoteConfig, NSError *error) {
        if (error) {
            // On error, no rate limiting
            [super executeRequest:request];
            return;
        }
        NSNumber *limit = remoteConfig.data[WP_REMOTE_CONFIG_ANONYMOUS_API_CLIENT_RATE_LIMIT_LIMIT] ?: ANONYMOUS_API_CLIENT_RATE_LIMIT_LIMIT;
        NSNumber *timeToLiveMilliseconds = remoteConfig.data[WP_REMOTE_CONFIG_ANONYMOUS_API_CLIENT_RATE_LIMIT_TIME_TO_LIVE_MILLISECONDS] ?: ANONYMOUS_API_CLIENT_RATE_LIMIT_TIME_TO_LIVE_MILLISECONDS;
        WPRateLimit *rateLimit = [[WPRateLimit alloc] initWithKey:@"AnonymousAPIClient" timeToLive:timeToLiveMilliseconds.doubleValue / 1000 limit:limit.unsignedIntegerValue];
        
        if ([WPRateLimiter.rateLimiter isRateLimited:rateLimit]) {
            // Retry later
            double delayInSeconds = 10;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self executeRequest:request];
            });
        } else {
            [WPRateLimiter.rateLimiter increment:rateLimit];
            [super executeRequest:request];
        }
    }];
    
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
