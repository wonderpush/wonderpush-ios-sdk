//
//  WPJsonSyncLiveActivity.m
//  WonderPush
//
//  Created by Olivier Favre on 02/02/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

#import "WPJsonSyncLiveActivity.h"

#import <Foundation/Foundation.h>
#import "WPConfiguration.h"
#import "WonderPush_private.h"
#import "WPInstallationCoreProperties.h"
#import "WPUtil.h"
#import <WonderPushCommon/WPLog.h>
#import <WonderPushCommon/WPErrors.h>
#import <WonderPushCommon/WPNSUtil.h>

#define UPGRADE_META_VERSION_KEY @"version"
#define UPGRADE_META_VERSION_0_INITIAL @0
#define UPGRADE_META_VERSION_LATEST UPGRADE_META_VERSION_0_INITIAL

#define STATE_META @"__jsonSyncLiveActivityMeta"
#define STATE_META_ACTIVITY_ID @"activityId"
#define STATE_META_USER_ID @"userId"
#define STATE_META_ACTIVITY_STATE @"activityState"
#define STATE_META_ATTRIBUTES_TYPE_NAME @"attributesTypeName"
#define STATE_META_CREATION_DATE @"creationDate"

#define ACTIVITY_STATE_ACTIVE @"active"
#define ACTIVITY_STATE_DISMISSED @"dismissed"
#define ACTIVITY_STATE_STALE @"stale"
#define ACTIVITY_STATE_ENDED @"ended"

BOOL isActivityStateTerminal(NSString  * _Nullable activityState) {
    return [activityState isKindOfClass:NSString.class] &&
        (
         [activityState isEqualToString:ACTIVITY_STATE_ENDED]
         || [activityState isEqualToString:ACTIVITY_STATE_DISMISSED]
         );
}

static BOOL patchCallDisabled = NO;

static NSObject *saveLock = nil;

@interface WPJsonSyncLiveActivity ()

@property (readonly, nonnull) NSString *activityId;
@property (readonly, nullable) NSString *userId; // userId used when creating the Live Activity, kept throughout its life-cycle
@property NSObject *blockId_lock;
@property int blockId;
@property NSDate *firstDelayedWriteDate;

- (void) save:(NSDictionary *)state;

- (void) scheduleServerPatchCallCallback;

- (void) serverPatchCallbackWithDiff:(NSDictionary *)diff onSuccess:(WPJsonSyncCallback)onSuccess onFailure:(WPJsonSyncCallback)onFailure;

@end

@implementation WPJsonSyncLiveActivity

+ (void) initialize {
    saveLock = [NSObject new];
}

+ (nullable NSDictionary *) metaFromSavedState:(nullable NSDictionary *)savedState {
    if (savedState == nil) {
        return nil;
    }
    NSDictionary *sdkState = [[WPJsonSync alloc] initFromSavedState:savedState saveCallback:^(NSDictionary *state) {
        // NOOP
    } serverPatchCallback:^(NSDictionary *diff, WPJsonSyncCallback onSuccess, WPJsonSyncCallback onFailure) {
        // NOOP
    } schedulePatchCallCallback:^{
        // NOOP
    } upgradeCallback:^(NSMutableDictionary *upgradeMeta, NSMutableDictionary *sdkState, NSMutableDictionary *serverState, NSMutableDictionary *putAccumulator, NSMutableDictionary *inflightDiff, NSMutableDictionary *inflightPutAccumulator) {
        // NOOP
    }].sdkState;
    return [WPNSUtil dictionaryForKey:STATE_META inDictionary:sdkState];
}

+ (nullable NSString *) activityIdFromSavedState:(nullable NSDictionary *)savedState {
    return [WPNSUtil stringForKey:STATE_META_ACTIVITY_ID inDictionary:[self metaFromSavedState:savedState]];
}

+ (nullable NSString *) attributesTypeNameFromSavedState:(nullable NSDictionary *)savedState {
    return [WPNSUtil stringForKey:STATE_META_ATTRIBUTES_TYPE_NAME inDictionary:[self metaFromSavedState:savedState]];
}

+ (void)setDisabled:(BOOL)disabled {
    patchCallDisabled = disabled;
}

+ (BOOL)disabled {
    return patchCallDisabled;
}

- (nullable instancetype) init_common {
    // Read input from stored meta
    NSDictionary *meta = [WPNSUtil dictionaryForKey:STATE_META inDictionary:self.sdkState];
    NSString *activityId = [WPNSUtil stringForKey:STATE_META_ACTIVITY_ID inDictionary:meta];
    NSString *userId = [WPNSUtil stringForKey:STATE_META_USER_ID inDictionary:meta];

    if (activityId == nil) {
        return nil;
    }
    _activityId = activityId;

    if (![userId length]) userId = nil;
    _userId = userId;

    _blockId_lock = [NSObject new];
    _blockId = 0;

    return self;
}

- (nullable instancetype) initFromSavedStateForActivityId:(nonnull NSString *)activityId {
    WPConfiguration *sharedConf = [WPConfiguration sharedConfiguration];
    NSDictionary *liveActivitySyncStatePerActivityId = [sharedConf liveActivitySyncStatePerActivityId];
    NSDictionary *liveActivitySyncState = [WPNSUtil dictionaryForKey:activityId inDictionary:liveActivitySyncStatePerActivityId];
    if (liveActivitySyncState == nil) {
        return nil;
    }
    self = [super initFromSavedState:liveActivitySyncState
                        saveCallback:^(NSDictionary *state) {
        [self save:state];
    }
                  serverPatchCallback:^(NSDictionary *diff, WPJsonSyncCallback onSuccess, WPJsonSyncCallback onFailure) {
        [self serverPatchCallbackWithDiff:diff onSuccess:onSuccess onFailure:onFailure];
    }
            schedulePatchCallCallback:^{
        [self scheduleServerPatchCallCallback];
    }
                      upgradeCallback:^(NSMutableDictionary *upgradeMeta, NSMutableDictionary *sdkState, NSMutableDictionary *serverState, NSMutableDictionary *putAccumulator, NSMutableDictionary *inflightDiff, NSMutableDictionary *inflightPutAccumulator) {
        NSNumber *currentVersion = [WPNSUtil numberForKey:UPGRADE_META_VERSION_KEY inDictionary:upgradeMeta] ?: UPGRADE_META_VERSION_0_INITIAL;
        if ([currentVersion compare:UPGRADE_META_VERSION_LATEST] != NSOrderedAscending) {
            // Do not alter current, or future versions we don't understand
            return;
        }
        upgradeMeta[UPGRADE_META_VERSION_KEY] = UPGRADE_META_VERSION_LATEST;
    }
    ];
    if (self) {
        self = [self init_common];
    }
    return self;
}

- (instancetype) initWithActivityId:(nonnull NSString *)activityId userId:(nullable NSString *)userId attributesTypeName:(nonnull NSString *)attributesTypeName {
    NSNumber *creationDate = [NSNumber numberWithLong:NSDate.date.timeIntervalSince1970 * 1000];
    self = [super initFromSdkState:@{
        STATE_META: @{
            STATE_META_USER_ID: userId ?: @"",
            STATE_META_ACTIVITY_ID: activityId,
            STATE_META_ACTIVITY_STATE: [NSNull null],
            STATE_META_ATTRIBUTES_TYPE_NAME: attributesTypeName,
            STATE_META_CREATION_DATE: creationDate,
        },
    }
                    andServerState:@{
        STATE_META: @{
            STATE_META_USER_ID: userId ?: @"",
            STATE_META_ACTIVITY_ID: activityId,
            STATE_META_ACTIVITY_STATE: [NSNull null],
            STATE_META_ATTRIBUTES_TYPE_NAME: attributesTypeName,
            STATE_META_CREATION_DATE: creationDate,
        },
    }
                      saveCallback:^(NSDictionary *state) {
        [self save:state];
    }
               serverPatchCallback:^(NSDictionary *diff, WPJsonSyncCallback onSuccess, WPJsonSyncCallback onFailure) {
        [self serverPatchCallbackWithDiff:diff onSuccess:onSuccess onFailure:onFailure];
    }
         schedulePatchCallCallback:^{
        [self scheduleServerPatchCallCallback];
    }
                   upgradeCallback:^(NSMutableDictionary *upgradeMeta, NSMutableDictionary *sdkState, NSMutableDictionary *serverState, NSMutableDictionary *putAccumulator, NSMutableDictionary *inflightDiff, NSMutableDictionary *inflightPutAccumulator) {
        upgradeMeta[UPGRADE_META_VERSION_KEY] = UPGRADE_META_VERSION_LATEST;
    }
    ];
    if (self) {
        self = [self init_common];
    }
    return self;
}

- (void) flush {
    @synchronized (_blockId_lock) {
        // Prevent any block from running
        _blockId++;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self performScheduledPatchCall];
    });
}

- (void) activityNoLongerExists {
    [self put:@{
        STATE_META: @{
            STATE_META_ACTIVITY_STATE: ACTIVITY_STATE_ENDED,
        },
        @"lifecycle": ACTIVITY_STATE_ENDED,
    }];

    // The activity no longer exists, flush right away
    [self flush];
}

- (void) activityChangedWithAttributesType:(NSString *)attributesTypeName activityState:(NSString *)activityState pushToken:(nullable NSData *)pushToken staleDate:(nullable NSDate *)staleDate relevanceScore:(nullable NSNumber *)relevanceScore topic:(NSString *)topic custom:(nullable NSDictionary *)custom {
    NSString *previousActivityState = self.sdkState[STATE_META][STATE_META_ACTIVITY_STATE];
    NSDate *creationDate = [NSDate date];
    NSNumber *creationDateNumber = [WPNSUtil numberForKey:STATE_META_CREATION_DATE inDictionary:self.sdkState[STATE_META]];
    if (creationDateNumber != nil) {
        creationDate = [NSDate dateWithTimeIntervalSince1970:creationDateNumber.floatValue/1000.f];
    }

    NSMutableDictionary *stateDiff = [NSMutableDictionary new];
    NSMutableDictionary *stateDiffMeta = [NSMutableDictionary new];
    stateDiff[STATE_META] = stateDiffMeta;

    // Add core properties.
    NSNull *null = [NSNull null];
    stateDiff[@"application"] = @{
        @"version" : [WPInstallationCoreProperties getVersionString] ?: null,
        @"sdkVersion": [WPInstallationCoreProperties getSDKVersionNumber] ?: null,
        @"integrator": [WonderPush getIntegrator] ?: null,
        @"apple": @{
            @"apsEnvironment": [WPUtil getEntitlement:@"aps-environment"] ?: null,
            @"appId": [WPUtil getEntitlement:@"application-identifier"] ?: null,
        },
    };
    CGRect screenSize = [WPInstallationCoreProperties getScreenSize];
    stateDiff[@"device"] = @{
        @"id": [WPUtil deviceIdentifier] ?: null,
        @"platform": @"iOS",
        @"osVersion": [WPInstallationCoreProperties getOsVersion] ?: null,
        @"brand": @"Apple",
        @"category": @"mobile",
        @"model": [WPInstallationCoreProperties getDeviceModel] ?: null,
        @"screenWidth": [NSNumber numberWithInt:(int)screenSize.size.width] ?: null,
        @"screenHeight": [NSNumber numberWithInt:(int)screenSize.size.height] ?: null,
        @"screenDensity": [NSNumber numberWithInt:(int)[WPInstallationCoreProperties getScreenDensity]] ?: null,
        @"configuration": @{
            @"timeZone": [WPInstallationCoreProperties getTimezone] ?: null,
            @"timeOffset": [WPInstallationCoreProperties getTimeOffset] ?: null,
            @"carrier": [WPInstallationCoreProperties getCarrierName] ?: null,
            @"country": [WPInstallationCoreProperties getCountry] ?: null,
            @"currency": [WPInstallationCoreProperties getCurrency] ?: null,
            @"locale": [WPInstallationCoreProperties getLocale] ?: null,
        },
    };

    stateDiff[@"type"] = attributesTypeName;

    stateDiffMeta[STATE_META_ACTIVITY_STATE] = activityState;
    stateDiff[@"lifecycle"] = activityState;

    stateDiff[@"staleDate"] = staleDate == nil ? null : [NSNumber numberWithLong:[staleDate timeIntervalSince1970] * 1000];
    stateDiff[@"relevanceScore"] = relevanceScore ?: null;

    if (pushToken != nil) {
        // Let's not remove the push token (except if explicitly given as empty).
        // In case iOS starts listing pre-existing Live Activities without one until is (suposedly) can get an updated value online,
        // doing this way protects us from temporarily removing the push token in the JsonSync.
        if ([pushToken length] == 0) {
            stateDiff[@"pushToken"] = null;
        } else {
            NSMutableDictionary *stateDiffPushToken = [NSMutableDictionary new];
            stateDiff[@"pushToken"] = stateDiffPushToken;
            stateDiffPushToken[@"data"] = [WPNSUtil hexForData:pushToken];
            stateDiffPushToken[@"expirationDate"] = [NSNumber numberWithLong:[[creationDate dateByAddingTimeInterval:8*60*60] timeIntervalSince1970] * 1000];
        }
    }
    stateDiffMeta[STATE_META_CREATION_DATE] = [NSNumber numberWithLong:[creationDate timeIntervalSince1970] * 1000];
    stateDiff[@"creationDate"] = [NSNumber numberWithLong:[creationDate timeIntervalSince1970] * 1000];

    stateDiff[@"topic"] = topic;
    stateDiff[@"custom"] = null; // in order to replace the whole custom object, we first need to clear it
    
    // Apply diff, temporarily clearing `custom`
    [self put:stateDiff];
    // Re-apply `custom` to finish replacing it entirely (we're not given a diff but a full value to apply)
    [self put:@{
        @"custom": custom ?: null,
    }];

    NSString *newActivityState = self.sdkState[STATE_META][STATE_META_ACTIVITY_STATE];
    if (isActivityStateTerminal(newActivityState) && !isActivityStateTerminal(previousActivityState)) {
        // The activity has just finished, flush without waiting as no ulterior changes will change it's server state.
        [self flush];
    }
}

- (void) save:(NSDictionary *)state {
    @synchronized (saveLock) {
        WPConfiguration *conf = [WPConfiguration sharedConfiguration];
        NSMutableDictionary *liveActivitySyncStatePerActivityId = [(conf.liveActivitySyncStatePerActivityId ?: @{}) mutableCopy];
        liveActivitySyncStatePerActivityId[_activityId] = state ?: @{};
        conf.liveActivitySyncStatePerActivityId = [liveActivitySyncStatePerActivityId copy];
    }
}

- (void) scheduleServerPatchCallCallback {
    //WPLogDebug(@"Scheduling a delayed update of Live Activity");
    if (![WonderPush hasUserConsent]) {
        [WonderPush safeDeferWithConsent:^{
            WPLogDebug(@"Now scheduling user consent delayed patch call for installation state for Live Activity id %@", self.activityId);
            [self scheduleServerPatchCallCallback]; // NOTE: imposes this function to be somewhat reentrant
        }];
        return;
    }
    @synchronized (_blockId_lock) {
        int currentBlockId = ++_blockId;
        NSDate *now = [NSDate date];
        if (!_firstDelayedWriteDate) {
            _firstDelayedWriteDate = now;
        }
        NSTimeInterval delay = MIN(LIVE_ACTIVITY_JSONSYNC_MIN_DELAY,
                                   [_firstDelayedWriteDate timeIntervalSinceReferenceDate] + LIVE_ACTIVITY_JSONSYNC_MAX_DELAY
                                   - [now timeIntervalSinceReferenceDate]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @synchronized (self->_blockId_lock) {
                if (self->_blockId != currentBlockId) {
                    return;
                }
                self->_firstDelayedWriteDate = nil;
            }
            //WPLogDebug(@"Performing delayed update of Live Activity");
            [self performScheduledPatchCall];
        });
    }
}

- (bool) performScheduledPatchCall
{
    if (![WonderPush hasUserConsent]) {
        WPLogDebug(@"Need consent, not performing scheduled patch call for Live Activity id %@", self.activityId);
        return false;
    }
    return [super performScheduledPatchCall];
}

- (void) serverPatchCallbackWithDiff:(NSDictionary *)diff onSuccess:(WPJsonSyncCallback)onSuccess onFailure:(WPJsonSyncCallback)onFailure {
    if (patchCallDisabled) {
        WPLogDebug(@"JsonSyncLiveActivity PATCH calls disabled.");
        if (onFailure) onFailure();
        return;
    }
    
    // Extract and remove STATE_META key from diff
    NSDictionary *diffMeta = [WPNSUtil dictionaryForKey:STATE_META inDictionary:diff];
    diff = [[NSMutableDictionary alloc] initWithDictionary:diff];
    [(NSMutableDictionary *)diff removeObjectForKey:STATE_META];

    NSDictionary *statePushToken = [WPNSUtil dictionaryForKey:@"pushToken" inDictionary:self.sdkState];
    NSString *statePushTokenData = [WPNSUtil stringForKey:@"data" inDictionary:statePushToken];

    NSString *diffMetaActivityState = [WPNSUtil stringForKey:STATE_META_ACTIVITY_STATE inDictionary:diffMeta];
    NSDictionary *serverMeta = [WPNSUtil dictionaryForKey:STATE_META inDictionary:self.serverState];
    NSString *serverMetaActivityState = [WPNSUtil stringForKey:STATE_META_ACTIVITY_STATE inDictionary:serverMeta];
    if (isActivityStateTerminal(diffMetaActivityState)) {
        // In the diff we're seeing the Live Activity no longer being active.
        // This means we must inform the server to delete the Live Activity.
        WPLogDebug(@"Deleting Live Activity for diff: %@ for Live Activity id %@", diff, _activityId);
        [WonderPush requestForUser:_userId
                            method:@"DELETE"
                          resource:[@"/liveActivities/" stringByAppendingString:_activityId]
                            params:@{}
                           handler:^(WPResponse *response, NSError *error) {
            NSDictionary *responseJson = (NSDictionary *)response.object;
            if (!error && [responseJson isKindOfClass:[NSDictionary class]] && [[WPNSUtil numberForKey:@"success" inDictionary:responseJson] boolValue]) {
                WPLogDebug(@"Succeded to delete Live Activity id %@: %@", self->_activityId, responseJson);
                onSuccess();
            } else {
                if ([error.domain isEqualToString:WPErrorDomain]
                    && error.code == WPErrorClientDisabled) {
                    // Hide this error on released SDKs (it's just for us).
                    //WPLogDebug(@"Failed to delete Live Activity id %@ because client is disabled: %@", self->_userId, error.localizedDescription);
                } else {
                    WPLogDebug(@"Failed to delete Live Activity id %@: error %@, response %@", self->_activityId, error, response);
                }
                onFailure();
            }
        }];
    } else if (isActivityStateTerminal(serverMetaActivityState)) {
        // We have already removed the Live Activity server-side (otherwise we would be in the previous case), so now we're no longer interested in its modifications
        WPLogDebug(@"Dropping Live Activity diff: %@ for Live Activity id %@ that is already deleted", diff, _activityId);
        onSuccess();
    } else if ([diff count] == 0) {
        // Meta-only change, there's nothing to send
        WPLogDebug(@"Auto-applying Live Activity meta-only diff: %@ for Live Activity id %@", diff, _activityId);
        onSuccess();
    } else if (statePushTokenData == nil) {
        // We have modifications to send server-side, but we have no push token
        WPLogDebug(@"Delaying Live Activity diff: %@ for Live Activity id %@ that has no push token yet", diff, _activityId);
        onFailure();
    } else {
        // We have modifications to send server-side, and we have a push token
        WPLogDebug(@"Sending Live Activity diff: %@ for Live Activity id %@", diff, _activityId);
        [WonderPush requestForUser:_userId
                            method:@"PATCH"
                          resource:[@"/liveActivities/" stringByAppendingString:_activityId]
                            params:@{@"body": diff}
                           handler:^(WPResponse *response, NSError *error) {
            NSDictionary *responseJson = (NSDictionary *)response.object;
            if (!error && [responseJson isKindOfClass:[NSDictionary class]] && [[WPNSUtil numberForKey:@"success" inDictionary:responseJson] boolValue]) {
                WPLogDebug(@"Succeded to send diff for Live Activity id %@: %@", self->_activityId, responseJson);
                onSuccess();
            } else {
                if ([error.domain isEqualToString:WPErrorDomain]
                    && error.code == WPErrorClientDisabled) {
                    // Hide this error on released SDKs (it's just for us).
                    //WPLogDebug(@"Failed to send diff for Live Activity id %@ because client is disabled: %@", self->_userId, error.localizedDescription);
                } else {
                    WPLogDebug(@"Failed to send diff for Live Activity id %@: error %@, response %@", self->_activityId, error, response);
                }
                onFailure();
            }
        }];
    }
}

@end
