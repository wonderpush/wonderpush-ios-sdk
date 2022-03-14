//
//  WPAction.m
//  WonderPush
//
//  Created by Stéphane JAIS on 19/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPAction_private.h"
#import <WonderPushCommon/WPNSUtil.h>
#import <WonderPushCommon/WPLog.h>

@interface WPAction (SuperPrivate)
- (instancetype) initWithDictionaries:(NSArray<NSDictionary *> *)dictionaries targetUrl:(NSURL *_Nullable)targetUrl;
@end

@implementation WPAction {
    NSArray<WPActionFollowUp *> *_followUps;
    NSString * _targetUrlMode;
}

+ (nullable instancetype)actionWithDictionaries:(NSArray<NSDictionary *> *)dicts targetUrl:(NSURL * _Nullable)targetUrl {
    return [[WPAction alloc] initWithDictionaries:dicts targetUrl:targetUrl];
}

+ (nullable instancetype)actionWithDictionaries:(NSArray<NSDictionary *> *)dicts {
    return [[WPAction alloc] initWithDictionaries:dicts targetUrl:nil];
}

- (instancetype)initWithDictionaries:(NSArray<NSDictionary *> *)dicts targetUrl:(NSURL * _Nullable)targetUrl {
    if (self = [super init]) {
        NSMutableArray *followUps = [NSMutableArray new];
        for (NSDictionary *dict in dicts) {
            NSString *dictType = [WPNSUtil stringForKey:@"type" inDictionary:dict];
            if (dictType && [@"link" isEqualToString:dictType]) {
                NSString *URLString = [WPNSUtil stringForKey:@"url" inDictionary:dict];
                if (URLString) {
                    _targetUrl = [NSURL URLWithString:URLString];
                }
                NSString *targetUrlMode = [WPNSUtil stringForKey:@"targetUrlMode" inDictionary:dict];
                _targetUrlMode = targetUrlMode;
                continue;
            }
            WPActionFollowUp *followUp = [WPActionFollowUp actionFollowUpWithDictionary:dict];
            if (followUp) [followUps addObject:followUp];
        }
        _followUps = [NSArray arrayWithArray:followUps];
        if (targetUrl) _targetUrl = targetUrl;
    }
    return self;
}

- (NSArray<WPActionFollowUp *> *) followUps {
    return _followUps;
}

- (NSString *) targetUrlMode {
    return _targetUrlMode;
}

@end

@implementation WPActionFollowUp

+ (nullable instancetype) actionFollowUpWithDictionary:(NSDictionary *)dict {
    NSString *typeStr = [WPNSUtil stringForKey:@"type" inDictionary:dict];
    if (!typeStr) return nil;
    WPActionFollowUpType type;
    if ([typeStr isEqualToString:@"mapOpen"]) type = WPActionFollowUpTypeMapOpen;
    else if ([typeStr isEqualToString:@"method"]) type = WPActionFollowUpTypeMethod;
    else if ([typeStr isEqualToString:@"rating"]) type = WPActionFollowUpTypeRating;
    else if ([typeStr isEqualToString:@"trackEvent"]) type = WPActionFollowUpTypeTrackEvent;
    else if ([typeStr isEqualToString:@"updateInstallation"]) type = WPActionFollowUpTypeUpdateInstallation;
    else if ([typeStr isEqualToString:@"addProperty"]) type = WPActionFollowUpTypeAddProperty;
    else if ([typeStr isEqualToString:@"removeProperty"]) type = WPActionFollowUpTypeRemoveProperty;
    else if ([typeStr isEqualToString:@"resyncInstallation"]) type = WPActionFollowUpTypeResyncInstallation;
    else if ([typeStr isEqualToString:@"addTag"]) type = WPActionFollowUpTypeAddTag;
    else if ([typeStr isEqualToString:@"removeTag"]) type = WPActionFollowUpTypeRemoveTag;
    else if ([typeStr isEqualToString:@"removeAllTags"]) type = WPActionFollowUpTypeRemoveAllTags;
    else if ([typeStr isEqualToString:@"_dumpState"]) type = WPActionFollowUpTypeDumpState;
    else if ([typeStr isEqualToString:@"_overrideSetLogging"]) type = WPActionFollowUpTypeOverrideSetLogging;
    else if ([typeStr isEqualToString:@"_overrideNotificationReceipt"]) type = WPActionFollowUpTypeOverrideNotificationReceipt;
    else if ([typeStr isEqualToString:@"closeNotifications"]) type = WPActionFollowUpTypeCloseNotifications;
    else if ([typeStr isEqualToString:@"subscribeToNotifications"]) type = WPActionFollowUpTypeSubscribeToNotifications;
    else return nil;
    WPActionFollowUp *result = [[WPActionFollowUp alloc] initWithType:type];
    
    switch (result.type) {
        case WPActionFollowUpTypeMapOpen: {
            NSDictionary *mapData = [WPNSUtil dictionaryForKey:@"map" inDictionary:dict] ?: @{};
            NSDictionary *place = [WPNSUtil dictionaryForKey:@"place" inDictionary:mapData] ?: @{};
            NSDictionary *point = [WPNSUtil dictionaryForKey:@"point" inDictionary:place] ?: @{};
            result.latitude = [WPNSUtil numberForKey:@"lat" inDictionary:point];
            result.longitude = [WPNSUtil numberForKey:@"lon" inDictionary:point];
        }
            break;
        case WPActionFollowUpTypeMethod: {
            result.methodName = [WPNSUtil stringForKey:@"method" inDictionary:dict];
            result.methodArg = [WPNSUtil nullsafeObjectForKey:@"methodArg" inDictionary:dict];
        }
            break;
        case WPActionFollowUpTypeSubscribeToNotifications:
            break;
        case WPActionFollowUpTypeRating:
            break;
        case WPActionFollowUpTypeTrackEvent: {
            NSDictionary *event = [WPNSUtil dictionaryForKey:@"event" inDictionary:dict] ?: @{};
            NSString *type = [WPNSUtil stringForKey:@"type" inDictionary:event];
            if (!type) return nil;
            result.event = type;
            result.custom = [WPNSUtil dictionaryForKey:@"custom" inDictionary:event];
        }
            break;
        case WPActionFollowUpTypeUpdateInstallation: {
            NSNumber *appliedServerSide = [WPNSUtil numberForKey:@"appliedServerSide" inDictionary:dict];
            result.appliedServerSide = [appliedServerSide isEqual:@YES];
            NSDictionary *installation = [WPNSUtil dictionaryForKey:@"installation" inDictionary:dict];
            NSDictionary *directCustom = [WPNSUtil dictionaryForKey:@"custom" inDictionary:dict];
            if (installation == nil && directCustom != nil) {
                installation = @{@"custom":directCustom};
            }
            result.installation = installation;
        }
            break;
        case WPActionFollowUpTypeAddProperty: {
            result.custom = [WPNSUtil dictionaryForKey:@"custom" inDictionary:([WPNSUtil dictionaryForKey:@"installation" inDictionary:dict] ?: dict)];
        }
            break;
        case WPActionFollowUpTypeRemoveProperty: {
            result.custom = [WPNSUtil dictionaryForKey:@"custom" inDictionary:([WPNSUtil dictionaryForKey:@"installation" inDictionary:dict] ?: dict)];

        }
            break;
        case WPActionFollowUpTypeResyncInstallation: {
            result.installation = [WPNSUtil dictionaryForKey:@"installation" inDictionary:dict] ?: @{};
            result.reset = [[WPNSUtil numberForKey:@"reset" inDictionary:dict] isEqual:@YES];
            result.force = [[WPNSUtil numberForKey:@"force" inDictionary:dict] isEqual:@YES];
        }
            break;
        case WPActionFollowUpTypeAddTag:
        case WPActionFollowUpTypeRemoveTag:
            result.tags = [WPNSUtil arrayForKey:@"tags" inDictionary:dict];
            break;
        case WPActionFollowUpTypeRemoveAllTags:
            break;
        case WPActionFollowUpTypeDumpState:
            break;
        case WPActionFollowUpTypeOverrideSetLogging:
        case WPActionFollowUpTypeOverrideNotificationReceipt:
            result.force = [[WPNSUtil numberForKey:@"force" inDictionary:dict] isEqual:@YES];
            break;
        case WPActionFollowUpTypeCloseNotifications: {
            result.tags = @[];
            NSArray *tags = [WPNSUtil arrayForKey:@"tags" inDictionary:dict];
            NSString *tag = [WPNSUtil stringForKey:@"tag" inDictionary:dict];
            if ([tags isKindOfClass:NSArray.class]) result.tags = [result.tags arrayByAddingObjectsFromArray:tags];
            if ([tag isKindOfClass:NSString.class]) result.tags = [result.tags arrayByAddingObject:tag];
            result.category = [WPNSUtil stringForKey:@"category" inDictionary:dict];
            result.targetContentId = [WPNSUtil stringForKey:@"targetContentId" inDictionary:dict];
            result.threadId = [WPNSUtil stringForKey:@"threadId" inDictionary:dict];
        }
            break;
    }
    return result;
}
- (instancetype) initWithType:(WPActionFollowUpType)type {
    if (self = [super init]) {
        _type = type;
    }
    return self;
}

@end
