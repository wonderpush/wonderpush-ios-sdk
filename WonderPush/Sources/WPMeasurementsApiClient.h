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
- (instancetype) initWithClientId:(NSString *)clientId
                           secret:(NSString *)secret
                         deviceId:(NSString *)deviceId;
@end

NS_ASSUME_NONNULL_END
