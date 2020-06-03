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

+ (instancetype) sharedClient;

- (void) POST:(NSString*)path bodyParam:(id)bodyParam completionHandler:(void(^ _Nullable)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

@end

NS_ASSUME_NONNULL_END
