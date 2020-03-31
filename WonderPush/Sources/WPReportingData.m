//
//  WPReportingData.m
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPReportingData.h"

@implementation WPReportingData
- (instancetype) initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        id campaignId = [dict valueForKey:@"campaignId"];
        if (!campaignId || campaignId == [NSNull null]) campaignId = [dict valueForKey:@"c"];
        if (campaignId == [NSNull null]) campaignId = nil;
        _campaignId = [campaignId isKindOfClass:NSString.class] ? campaignId : nil;

        id notificationId = [dict valueForKey:@"notificationId"];
        if (!notificationId || notificationId == [NSNull null]) notificationId = [dict valueForKey:@"n"];
        if (notificationId == [NSNull null]) notificationId = nil;
        _notificationId = [notificationId isKindOfClass:NSString.class] ? notificationId : nil;

        id viewId = [dict valueForKey:@"viewId"];
        if (viewId == [NSNull null]) viewId = nil;
        _viewId = [viewId isKindOfClass:NSString.class] ? viewId : nil;
    }
    return self;
}
- (NSString *) description {
    return self.dictValue.description;
}
- (NSDictionary *) dictValue {
    NSMutableDictionary *result = [NSMutableDictionary new];
    if (_viewId) result[@"viewId"] = _viewId;
    if (_notificationId) result[@"notificationId"] = _notificationId;
    if (_campaignId) result[@"campaignId"] = _campaignId;
    return [NSDictionary dictionaryWithDictionary:result];
}
@end
