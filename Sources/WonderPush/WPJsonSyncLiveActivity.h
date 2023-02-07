//
//  WPJsonSyncLiveActivity.h
//  WonderPush
//
//  Created by Olivier Favre on 02/02/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

#ifndef WPJsonSyncLiveActivity_h
#define WPJsonSyncLiveActivity_h

#import "WPJsonSync.h"

@interface WPJsonSyncLiveActivity : WPJsonSync

+ (void) initialize;
+ (nullable NSString *) activityIdFromSavedState:(nullable NSDictionary *)savedState;
+ (nullable NSString *) attributesTypeNameFromSavedState:(nullable NSDictionary *)savedState;

- (nullable instancetype) initFromSavedStateForActivityId:(nonnull NSString *)activityId;
- (nonnull instancetype) initWithActivityId:(nonnull NSString *)activityId userId:(nullable NSString *)userId attributesTypeName:(nonnull NSString *)attributesTypeName;

- (void) flush;
- (void) activityNoLongerExists;
- (void) activityChangedWithAttributesType:(nullable NSString *)attributesTypeName creationDate:(nullable NSDate *)creationDate activityState:(nullable NSString *)activityState pushToken:(nullable NSData *)pushToken staleDate:(nullable NSDate *)staleDate relevanceScore:(nullable NSNumber *)relevanceScore topic:(nullable NSString *)topic custom:(nullable NSDictionary *)custom;

+ (void) setDisabled:(BOOL)disabled;
+ (BOOL) disabled;

@end

#endif /* WPJsonSyncLiveActivity_h */
