//
//  WPNotificationCategoryManager.m
//  WonderPush
//
//  Created by Stéphane JAIS on 24/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPNotificationCategoryManager.h"

#define MAX_NUMBER_OF_CATEGORIES 5

NSString * const kNotificationCategoryPrefix = @"WonderPushNotification";
NSString * const kNotificationCategorySeparator = @"_";
// FIXME: please keep in sync with kActionIdentifierPrefix defined in WPNotificationCategoryManager
NSString * const kActionIdentifierPrefix = @"WonderPush_";

@implementation WPNotificationCategoryManager
+ (instancetype) sharedInstance {
    static WPNotificationCategoryManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [WPNotificationCategoryManager new];
    });
    return sharedInstance;
}

- (NSString *)actionIdentifierForButtonAtIndex:(NSUInteger)index {
    return [kActionIdentifierPrefix stringByAppendingFormat:@"%lu", (unsigned long)index];
}

- (NSString *)categoryIdentifierWithNotificationId:(NSString *_Nullable)notificationId {
    NSString *currentTimeString = [NSString stringWithFormat:@"%.0f", [NSDate date].timeIntervalSince1970];
    NSArray *parts = [NSArray arrayWithObjects:
                      kNotificationCategoryPrefix,
                      currentTimeString,
                      notificationId ? [notificationId stringByReplacingOccurrencesOfString:kNotificationCategorySeparator withString:@""] : NSUUID.UUID.UUIDString,
                      nil];
    return [parts componentsJoinedByString:kNotificationCategorySeparator];
}

- (NSString *_Nullable)notificationIdFromCategoryIdentifier:(NSString *)categoryIdentifier {
    if (![self isCategoryIdentifierFromWonderPush:categoryIdentifier]) return nil;
    NSArray<NSString *> *parts = [categoryIdentifier componentsSeparatedByString:kNotificationCategorySeparator];
    if (parts.count == 3) return parts.lastObject;
    return nil;
}

- (BOOL) isCategoryIdentifierFromWonderPush:(NSString *)categoryIdentifier {
    return [categoryIdentifier hasPrefix:kNotificationCategoryPrefix];
}

- (UNNotificationCategory *_Nullable) registerNotificationCategoryIdentifierWithNotificationId:(NSString *)notificationId actions:(nonnull NSArray<UNNotificationAction *> *)actions  API_AVAILABLE(ios(10.0)){
    if (@available(iOS 10.0, *)) {
        NSString *categoryIdentifier = [self categoryIdentifierWithNotificationId:notificationId];
        UNNotificationCategory *category = [UNNotificationCategory
                                            categoryWithIdentifier:categoryIdentifier
                                            actions:actions
                                            intentIdentifiers:@[]
                                            options:UNNotificationCategoryOptionCustomDismissAction];

        // Sort categories by name descending. Because we name the categories after the date they were created, we'll get the most recent first
        NSArray<UNNotificationCategory*>* notificationCenterCategories = [self.notificationCenterCategories sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO]]];
        
        NSMutableSet<UNNotificationCategory *>* prunedNotificationCenterCategories = [NSMutableSet new];
        NSInteger ourCategoriesCounter = 0;
        for (UNNotificationCategory *existingCategory in notificationCenterCategories) {
            // Do not prune categories that are not ours
            if (![self isCategoryIdentifierFromWonderPush:existingCategory.identifier]) {
                [prunedNotificationCenterCategories addObject:existingCategory];
                continue;
            }
            NSString *existingNotificationId = [self notificationIdFromCategoryIdentifier:existingCategory.identifier];

            // Prune any category that represents the same notification
            if ([existingNotificationId isEqualToString:notificationId]) {
                continue;
            }
            // Do not let in more than MAX_NUMBER_OF_CATEGORIES - 1 (we'll add one right after this loop)
            if (ourCategoriesCounter >= MAX_NUMBER_OF_CATEGORIES - 1) {
                continue;
            }
            // Add this category
            ourCategoriesCounter++;
            [prunedNotificationCenterCategories addObject:existingCategory];
        }
        [prunedNotificationCenterCategories addObject:category];
        [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:prunedNotificationCenterCategories];
        // List Categories again so iOS refreshes it's internal list.
        notificationCenterCategories = self.notificationCenterCategories.allObjects;
        return category;
    };
    return nil;
}

- (NSSet<UNNotificationCategory*>*)notificationCenterCategories  API_AVAILABLE(ios(10.0)) {
    __block NSMutableSet* result;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notificationCenter getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *categories) {
        result = [categories copy];
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}
@end
