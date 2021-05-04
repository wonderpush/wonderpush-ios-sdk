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

+ (WPReportingData * _Nonnull) extract:(NSDictionary * _Nullable)source {
    if (![source isKindOfClass:NSDictionary.class]) source = @{};
    NSDictionary * _Nullable reporting = [WPNSUtil dictionaryForKey:@"reporting" inDictionary:source];
    if (source[@"n"] != nil || source[@"c"] != nil || source[@"v"] != nil) {
        return [[self alloc] initWithNotificationId:source[@"n"] campaignId:source[@"c"] viewId:source[@"v"] reporting:reporting];
    } else if (source[@"notificationId"] != nil || source[@"campaignId"] != nil || source[@"viewId"] != nil) {
        return [[self alloc] initWithNotificationId:source[@"notificationId"] campaignId:source[@"campaignId"] viewId:source[@"viewId"] reporting:reporting];
    } else if (reporting != nil) {
        return [[self alloc] initWithNotificationId:reporting[@"notificationId"] campaignId:reporting[@"campaignId"] viewId:reporting[@"viewId"] reporting:reporting];
    }
    return [[self alloc] initWithNotificationId:nil campaignId:nil viewId:nil reporting:nil];
}

- (instancetype) initFromSerialized:(NSDictionary *)serializationDict {
    return [self initWithNotificationId:[WPNSUtil stringForKey:@"notificationId" inDictionary:serializationDict]
                             campaignId:[WPNSUtil stringForKey:@"campaignId" inDictionary:serializationDict]
                                 viewId:[WPNSUtil stringForKey:@"viewId" inDictionary:serializationDict]
                              reporting:[WPNSUtil dictionaryForKey:@"reporting" inDictionary:serializationDict]];
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
