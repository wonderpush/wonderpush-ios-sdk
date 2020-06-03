//
//  WPMeasurementsApiClient.h
//  WonderPush
//
//  Created by Stéphane JAIS on 07/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define MEASUREMENTS_API_DOMAIN @"measurements-api.wonderpush.com"
#define MEASUREMENTS_API_URL @"https://" MEASUREMENTS_API_DOMAIN @"/v1/"

@interface WPMeasurementsApiClient : NSObject

- (instancetype) initWithClientId:(NSString *)clientId
                           secret:(NSString *)secret
                         deviceId:(NSString *)deviceId;

- (void) POST:(NSString*)path bodyParam:(id)bodyParam userId:(NSString * _Nullable)userId completionHandler:(void(^ _Nullable)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
