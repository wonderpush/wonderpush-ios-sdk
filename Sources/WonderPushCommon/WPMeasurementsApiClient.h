//
//  WPMeasurementsApiClient.h
//  WonderPush
//
//  Created by Stéphane JAIS on 07/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPBasicApiClient.h"

#define MEASUREMENTS_API_DOMAIN @"measurements-api.wonderpush.com"
#define MEASUREMENTS_API_URL @"https://" MEASUREMENTS_API_DOMAIN @"/v1/"

NS_ASSUME_NONNULL_BEGIN

@interface WPMeasurementsApiClient : WPBasicApiClient
- (instancetype) initWithClientId:(nullable NSString *)clientId
                           secret:(nullable NSString *)secret
                         deviceId:(nullable NSString *)deviceId;

/// Called live, once per decorated request body, to fill in the `_reachability` param. WonderPushCommon
/// has no access to WPConfiguration (WonderPush depends on WonderPushCommon, not the reverse), so the
/// WonderPush target wires this up when it builds the client, instead of this class computing it itself.
@property (nonatomic, copy, nullable) NSString * _Nullable (^reachabilityProvider)(void);
@end

NS_ASSUME_NONNULL_END
