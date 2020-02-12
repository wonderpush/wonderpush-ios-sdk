//
//  WPAction.m
//  WonderPush
//
//  Created by Stéphane JAIS on 19/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPAction_private.h"
#import "WPUtil.h"

@implementation WPAction {
    NSArray<WPActionFollowUp *> *_followUps;
}

+ (instancetype)actionWithDictionaries:(NSArray<NSDictionary *> *)dicts {
    NSURL *URL = nil;
    NSMutableArray *followUps = [NSMutableArray new];
    for (NSDictionary *dict in dicts) {
        if ([@"link" isEqualToString:[dict valueForKey:@"type"]]) {
            NSString *URLString = [dict valueForKey:@"url"];
            URL = [NSURL URLWithString:URLString];
            continue;
        }
        WPActionFollowUp *followUp = [WPActionFollowUp actionFollowUpWithDictionary:dict];
        if (followUp) [followUps addObject:followUp];
    }
    WPAction *action = [[WPAction alloc]
                        initWithURL:URL
                        followUps:[NSArray arrayWithArray:followUps]];
    return action;
}

- (NSArray<WPActionFollowUp *> *) followUps {
    return _followUps;
}

- (instancetype) initWithURL:(NSURL*)URL followUps:(NSArray<WPActionFollowUp *> *)followUps {
    if (self = [super init]) {
        _targetUrl = URL;
        _followUps = followUps;
    }
    return self;
}

@end

@implementation WPActionFollowUp

+ (nullable instancetype) actionFollowUpWithDictionary:(NSDictionary *)dict {
    NSString *typeStr = [dict valueForKey:@"type"];
    if (![typeStr isKindOfClass:[NSString class]]) return nil;
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
    else return nil;
    WPActionFollowUp *result = [[WPActionFollowUp alloc] initWithType:type];
    
    switch (result.type) {
        case WPActionFollowUpTypeMapOpen: {
            NSDictionary *mapData = [WPUtil dictionaryForKey:@"map" inDictionary:dict] ?: @{};
            NSDictionary *place = [WPUtil dictionaryForKey:@"place" inDictionary:mapData] ?: @{};
            NSDictionary *point = [WPUtil dictionaryForKey:@"point" inDictionary:place] ?: @{};
            result.latitude = [WPUtil numberForKey:@"lat" inDictionary:point];
            result.longitude = [WPUtil numberForKey:@"lon" inDictionary:point];
        }
            break;
        case WPActionFollowUpTypeMethod: {
            result.methodName = [WPUtil stringForKey:@"method" inDictionary:dict];
            result.methodArg = [WPUtil nullsafeObjectForKey:@"methodArg" inDictionary:dict];
        }
            break;
        case WPActionFollowUpTypeRating:
            break;
        case WPActionFollowUpTypeTrackEvent: {
            NSDictionary *event = [WPUtil dictionaryForKey:@"event" inDictionary:dict] ?: @{};
            NSString *type = [WPUtil stringForKey:@"type" inDictionary:event];
            if (!type) return nil;
            result.event = type;
            result.custom = [WPUtil dictionaryForKey:@"custom" inDictionary:event];
        }
            break;
        case WPActionFollowUpTypeUpdateInstallation: {
            NSNumber *appliedServerSide = [WPUtil numberForKey:@"appliedServerSide" inDictionary:dict];
            result.appliedServerSide = [appliedServerSide isEqual:@YES];
            NSDictionary *installation = [WPUtil dictionaryForKey:@"installation" inDictionary:dict];
            NSDictionary *directCustom = [WPUtil dictionaryForKey:@"custom" inDictionary:dict];
            if (installation == nil && directCustom != nil) {
                installation = @{@"custom":directCustom};
            }
            result.installation = installation;
        }
            break;
        case WPActionFollowUpTypeAddProperty: {
            result.custom = [WPUtil dictionaryForKey:@"custom" inDictionary:([WPUtil dictionaryForKey:@"installation" inDictionary:dict] ?: dict)];
        }
            break;
        case WPActionFollowUpTypeRemoveProperty: {
            result.custom = [WPUtil dictionaryForKey:@"custom" inDictionary:([WPUtil dictionaryForKey:@"installation" inDictionary:dict] ?: dict)];

        }
            break;
        case WPActionFollowUpTypeResyncInstallation: {
            result.installation = [WPUtil dictionaryForKey:@"installation" inDictionary:dict] ?: @{};
            result.reset = [[WPUtil numberForKey:@"reset" inDictionary:dict] isEqual:@YES];
            result.force = [[WPUtil numberForKey:@"force" inDictionary:dict] isEqual:@YES];
        }
            break;
        case WPActionFollowUpTypeAddTag:
        case WPActionFollowUpTypeRemoveTag:
            result.tags = [WPUtil arrayForKey:@"tags" inDictionary:dict];
            break;
        case WPActionFollowUpTypeRemoveAllTags:
            break;
        case WPActionFollowUpTypeDumpState:
            break;
        case WPActionFollowUpTypeOverrideSetLogging:
        case WPActionFollowUpTypeOverrideNotificationReceipt:
            result.force = [[WPUtil numberForKey:@"force" inDictionary:dict] isEqual:@YES];
            break;
        case WPActionFollowUpTypeCloseNotifications: {
            result.tags = @[];
            NSArray *tags = [WPUtil arrayForKey:@"tags" inDictionary:dict];
            NSString *tag = [WPUtil stringForKey:@"tag" inDictionary:dict];
            if ([tags isKindOfClass:NSArray.class]) result.tags = [result.tags arrayByAddingObjectsFromArray:tags];
            if ([tag isKindOfClass:NSString.class]) result.tags = [result.tags arrayByAddingObject:tag];
            result.category = [WPUtil stringForKey:@"category" inDictionary:dict];
            result.targetContentId = [WPUtil stringForKey:@"targetContentId" inDictionary:dict];
            result.threadId = [WPUtil stringForKey:@"threadId" inDictionary:dict];
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
