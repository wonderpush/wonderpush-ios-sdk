//
//  WPAnonymousAPIClient.h
//  WonderPush
//
//  Created by Stéphane JAIS on 12/07/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WonderPushCommon/WPRequest.h>
#import "WPAPIClient.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPAnonymousAPIClient : WPBaseAPIClient

/**
 The default `WPAPIClient`, configured with the values you supplied to [WonderPush setClientId:secret:].
 */
+ (WPAnonymousAPIClient *)sharedClient;

@end

NS_ASSUME_NONNULL_END
