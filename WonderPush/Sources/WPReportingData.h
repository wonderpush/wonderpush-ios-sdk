//
//  WPReportingData.h
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPReportingData : NSObject
@property (readonly, nullable) NSString *campaignId;
@property (readonly, nullable) NSString *notificationId;
@property (readonly, nullable) NSString *viewId;

- (instancetype) initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *) dictValue;

@end

NS_ASSUME_NONNULL_END
