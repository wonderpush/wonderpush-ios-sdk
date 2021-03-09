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
@property (readonly, nullable) NSDictionary *reporting;
@property (readonly, nullable) NSString *campaignId;
@property (readonly, nullable) NSString *notificationId;
@property (readonly, nullable) NSString *viewId;

+ (WPReportingData * _Nonnull) extract:(NSDictionary * _Nullable)source;

- (instancetype) initWithNotificationId:(NSString * _Nullable)notificationId campaignId:(NSString * _Nullable)campaignId viewId:(NSString * _Nullable)viewId reporting:(NSDictionary * _Nullable)reporting;
- (instancetype) initFromSerialized:(NSDictionary *)serializationDict;
- (instancetype) init NS_UNAVAILABLE;

- (NSDictionary *) serializationDictValue;
- (NSDictionary *) eventDataValue;
- (void) fillEventDataInto:(NSMutableDictionary *)eventData;
- (NSDictionary * _Nonnull) filledEventData:(NSDictionary * _Nullable)eventData;

@end

NS_ASSUME_NONNULL_END
