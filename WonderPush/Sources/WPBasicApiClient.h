//
//  WPBasicApiClient.h
//  WonderPush
//
//  Created by Stéphane JAIS on 12/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPRequest.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const WPBasicApiClientResponseNotification;
extern NSString * const WPBasicApiClientResponseNotificationRequestKey;
extern NSString * const WPBasicApiClientResponseNotificationClientKey;

@interface WPBasicApiClient : NSObject <WPRequestExecutor>
@property (nonatomic, assign) BOOL disabled;
@property (readonly, nonnull) NSURL *baseURL;
@property (readonly, nonnull) NSString *clientSecret;
@property (readonly, nonnull) NSArray<NSString *> *additionalAllowedParams;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithBaseURL:(NSURL *)baseURL clientSecret:(NSString *)clientSecret NS_DESIGNATED_INITIALIZER;
- (NSString * _Nullable) decorateRequestBody:(NSString * _Nullable)body userId:(NSString *)userId;

@end

NS_ASSUME_NONNULL_END
