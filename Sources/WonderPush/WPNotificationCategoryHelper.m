//
//  WPNotificationCategoryHelper.m
//  WonderPush
//
//  Created by Stéphane JAIS on 27/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPNotificationCategoryHelper.h"

// FIXME: please keep in sync with kActionIdentifierPrefix defined in WPNotificationCategoryManager
NSString * const kActionIdentifierPrefix = @"WonderPush_";

@implementation WPNotificationCategoryHelper
+ (instancetype) sharedInstance {
    static WPNotificationCategoryHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [WPNotificationCategoryHelper new];
    });
    return sharedInstance;
}

- (BOOL)isWonderPushActionIdentifier:(NSString *)actionIdentifier {
    return [actionIdentifier hasPrefix:kActionIdentifierPrefix];
}

- (NSInteger)indexOfButtonWithActionIdentifier:(NSString *)actionIdentifier {
    if ([self isWonderPushActionIdentifier:actionIdentifier]) {
        return [actionIdentifier substringFromIndex:kActionIdentifierPrefix.length].intValue;
    }
    return -1;
}

@end
