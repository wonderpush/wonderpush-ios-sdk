//
//  WPAction_private.h
//  WonderPush
//
//  Created by Stéphane JAIS on 19/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <WonderPush/WPAction.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    WPActionFollowUpTypeMapOpen,
    WPActionFollowUpTypeMethod,
    WPActionFollowUpTypeRating,
    WPActionFollowUpTypeTrackEvent,
    WPActionFollowUpTypeUpdateInstallation,
    WPActionFollowUpTypeAddProperty,
    WPActionFollowUpTypeRemoveProperty,
    WPActionFollowUpTypeResyncInstallation,
    WPActionFollowUpTypeAddTag,
    WPActionFollowUpTypeRemoveTag,
    WPActionFollowUpTypeRemoveAllTags,
    WPActionFollowUpTypeDumpState,
    WPActionFollowUpTypeOverrideSetLogging,
    WPActionFollowUpTypeOverrideNotificationReceipt,
    WPActionFollowUpTypeCloseNotifications,
    WPActionFollowUpTypeSubscribeToNotifications,
} WPActionFollowUpType;

@interface WPActionFollowUp : NSObject
@property (nonatomic, assign) WPActionFollowUpType type;
@property (nonatomic, nullable, strong) NSString *event;
@property (nonatomic, nullable, strong) NSDictionary *custom;
@property (nonatomic, nullable, strong) NSDictionary *installation;
@property (nonatomic, nullable, strong) NSArray<NSString *> *tags;
@property (nonatomic, nullable, strong) NSString *methodName;
@property (nonatomic, nullable, strong) id methodArg;
@property (nonatomic, nullable, strong) NSNumber *latitude;
@property (nonatomic, nullable, strong) NSNumber *longitude;
@property (nonatomic, nullable, strong) NSString *category;
@property (nonatomic, nullable, strong) NSString *threadId;
@property (nonatomic, nullable, strong) NSString *targetContentId;
@property (nonatomic, assign) BOOL appliedServerSide;
@property (nonatomic, assign) BOOL reset;
@property (nonatomic, assign) BOOL force;

+ (nullable instancetype) actionFollowUpWithDictionary:(NSDictionary *)dict;
- (instancetype) initWithType:(WPActionFollowUpType)type;
@end

@interface WPAction (Private)
@property (nonatomic, readonly) NSArray<WPActionFollowUp *> *followUps;
@property (nonatomic, nullable, readonly) NSString *targetUrlMode;

+ (nullable instancetype)actionWithDictionaries:(NSArray<NSDictionary *> *)dicts;
+ (nullable instancetype)actionWithDictionaries:(NSArray<NSDictionary *> *)dicts targetUrl:(NSURL *_Nullable)targetUrl;
- (instancetype) init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
