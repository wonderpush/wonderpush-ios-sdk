//
//  WPReportingData.m
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPReportingData.h"
#import "WPNSUtil.h"
#import "WonderPush_constants.h"

@implementation WPReportingData

- (instancetype) initWithNotificationId:(NSString * _Nullable)notificationId campaignId:(NSString * _Nullable)campaignId viewId:(NSString * _Nullable)viewId reporting:(NSDictionary * _Nullable)reporting {
    if (self = [super init]) {
        _notificationId = [notificationId isKindOfClass:NSString.class] ? notificationId : nil;
        _campaignId = [campaignId isKindOfClass:NSString.class] ? campaignId : nil;
        _viewId = [viewId isKindOfClass:NSString.class] ? viewId : nil;
        _reporting = [reporting isKindOfClass:NSDictionary.class] ? reporting : nil;
    }
    return self;
}

- (instancetype) initWithReporting:(NSDictionary *)reporting {
    return [self initWithNotificationId:[WPNSUtil stringForKey:@"notificationId" inDictionary:reporting]
                             campaignId:[WPNSUtil stringForKey:@"campaignId" inDictionary:reporting]
                                 viewId:[WPNSUtil stringForKey:@"viewId" inDictionary:reporting]
                              reporting:reporting];
}

- (instancetype)initWithPushPayload:(NSDictionary *)userInfo {
    NSDictionary *wpData = [WPNSUtil dictionaryForKey:WP_PUSH_NOTIFICATION_KEY inDictionary:userInfo];
    return [self initWithPushWpData:wpData];
}

- (instancetype)initWithPushWpData:(NSDictionary *)wpData {
    NSString * _Nullable notificationId = [WPNSUtil stringForKey:@"n" inDictionary:wpData];
    NSString * _Nullable campaignId = [WPNSUtil stringForKey:@"c" inDictionary:wpData];
    NSString * _Nullable viewId = [WPNSUtil stringForKey:@"v" inDictionary:wpData];
    NSDictionary *reporting = [WPNSUtil dictionaryForKey:@"reporting" inDictionary:wpData];
    // Fallback on the reporting dictionary if the short fields are absent
    if (!notificationId) {
        notificationId = [WPNSUtil stringForKey:@"notificationId" inDictionary:reporting];
    }
    if (!campaignId) {
        campaignId = [WPNSUtil stringForKey:@"campaignId" inDictionary:reporting];
    }
    if (!viewId) {
        viewId = [WPNSUtil stringForKey:@"viewId" inDictionary:reporting];
    }
    return [self initWithNotificationId:notificationId
                             campaignId:campaignId
                                 viewId:viewId
                              reporting:reporting];
}

// Note: Currently used by initWithEventData: and initWithNotificationDict: because it's identical as of now
- (instancetype) initWithSerializationDict:(NSDictionary *)serializationDict {
    return [self initWithNotificationId:[WPNSUtil stringForKey:@"notificationId" inDictionary:serializationDict]
                             campaignId:[WPNSUtil stringForKey:@"campaignId" inDictionary:serializationDict]
                                 viewId:[WPNSUtil stringForKey:@"viewId" inDictionary:serializationDict]
                              reporting:[WPNSUtil dictionaryForKey:@"reporting" inDictionary:serializationDict]];
}

- (instancetype)initWithEventData:(NSDictionary *)eventData {
    return [self initWithSerializationDict:eventData];
}

- (instancetype)initWithNotificationDict:(NSDictionary *)notificationDict {
    return [self initWithSerializationDict:notificationDict];
}

- (NSString *) description {
    return self.serializationDictValue.description;
}

// Note: Currently used by initWithEventData: and initWithNotificationDict: because it's identical as of now
//       Hence, any new key written here should be added in the check of canFillEventData:
- (NSDictionary *) serializationDictValue {
    NSMutableDictionary *result = [NSMutableDictionary new];
    if (_notificationId) result[@"notificationId"] = _notificationId;
    if (_campaignId) result[@"campaignId"] = _campaignId;
    if (_viewId) result[@"viewId"] = _viewId;
    if (_reporting) result[@"reporting"] = _reporting;
    return [NSDictionary dictionaryWithDictionary:result];
}

// Any new key written here should be added in the check of canFillEventData:
- (NSDictionary *) eventDataValue {
    return [self serializationDictValue];
}

// We should check for *ALL* the keys we might write in eventDataValue: before overwriting any
- (BOOL) canFillEventData:(NSDictionary * _Nullable)eventData {
    return eventData[@"notificationId"] == nil
        && eventData[@"campaignId"] == nil
        && eventData[@"viewId"] == nil
        && eventData[@"reporting"] == nil;
}

// We should check for *ALL* the keys we might write in eventDataValue: before overwriting any
- (void) fillEventDataInto:(NSMutableDictionary *)eventData {
    if ([self canFillEventData:eventData]) {
        [eventData addEntriesFromDictionary:self.eventDataValue];
    }
}

- (NSDictionary * _Nonnull) filledEventData:(NSDictionary * _Nullable)eventData {
    if (eventData == nil) {
        eventData = @{};
    }
    if ([self canFillEventData:eventData]) {
        NSMutableDictionary *mutableEventData = [[NSMutableDictionary alloc] initWithDictionary:eventData];
        [mutableEventData addEntriesFromDictionary:self.eventDataValue];
        return [NSDictionary dictionaryWithDictionary:mutableEventData];
    }
    return eventData;
}

@end
