#import "WPJsonSync.h"

#import <WonderPushCommon/WPJsonUtil.h>
#import <WonderPushCommon/WPLog.h>
#import <WonderPushCommon/WPNSUtil.h>


#define SAVED_STATE_FIELD__SYNC_STATE_VERSION @"_syncStateVersion"
#define SAVED_STATE_STATE_VERSION_1 @1
#define SAVED_STATE_STATE_VERSION_2 @2
#define SAVED_STATE_FIELD_UPGRADE_META @"upgradeMeta"
#define SAVED_STATE_FIELD_SDK_STATE @"sdkState"
#define SAVED_STATE_FIELD_SERVER_STATE @"serverState"
#define SAVED_STATE_FIELD_PUT_ACCUMULATOR @"putAccumulator"
#define SAVED_STATE_FIELD_INFLIGHT_DIFF @"inflightDiff"
#define SAVED_STATE_FIELD_INFLIGHT_PUT_ACCUMULATOR @"inflightPutAccumulator"
#define SAVED_STATE_FIELD_SCHEDULED_PATCH_CALL @"scheduledPatchCall"
#define SAVED_STATE_FIELD_INFLIGHT_PATCH_CALL @"inflightPatchCall"



@interface WPJsonSync ()


@property WPJsonSyncServerPatchCallback serverPatchCallback;
@property WPJsonSyncSaveCallback saveCallback;
@property WPJsonSyncCallback schedulePatchCallCallback;

@property (atomic, strong) NSDictionary *sdkState;
@property (atomic, strong) NSDictionary *serverState;
@property (copy) NSDictionary *upgradeMeta;
@property (copy) NSDictionary *putAccumulator;
@property (copy) NSDictionary *inflightDiff;
@property (copy) NSDictionary *inflightPutAccumulator;

- (void) schedulePatchCallAndSave;
- (void) save;
- (void) callPatch;

- (void) onSuccess;
- (void) onFailure;


@end



@implementation WPJsonSync

- (instancetype) initFromSavedState:(NSDictionary *)savedState saveCallback:(WPJsonSyncSaveCallback)saveCallback serverPatchCallback:(WPJsonSyncServerPatchCallback)serverPatchCallback schedulePatchCallCallback:(WPJsonSyncCallback)schedulePatchCallCallback upgradeCallback:(WPJsonSyncUpgradeCallback _Nullable)upgradeCallback {
    self = [super init];
    if (self) {
        _serverPatchCallback = serverPatchCallback;
        _saveCallback = saveCallback;
        _schedulePatchCallCallback = schedulePatchCallCallback;

        savedState = savedState ?: @{};
        NSNumber *syncStateVersion;
        syncStateVersion        = [WPNSUtil numberForKey:SAVED_STATE_FIELD__SYNC_STATE_VERSION inDictionary:savedState] ?: @0;
        _upgradeMeta            = [WPNSUtil dictionaryForKey:SAVED_STATE_FIELD_UPGRADE_META inDictionary:savedState] ?: @{};
        self.sdkState           = [WPNSUtil dictionaryForKey:SAVED_STATE_FIELD_SDK_STATE inDictionary:savedState] ?: @{};
        self.serverState        = [WPNSUtil dictionaryForKey:SAVED_STATE_FIELD_SERVER_STATE inDictionary:savedState] ?: @{};
        _putAccumulator         = [WPNSUtil dictionaryForKey:SAVED_STATE_FIELD_PUT_ACCUMULATOR inDictionary:savedState] ?: @{};
        _inflightDiff           = [WPNSUtil dictionaryForKey:SAVED_STATE_FIELD_INFLIGHT_DIFF inDictionary:savedState] ?: @{};
        _inflightPutAccumulator = [WPNSUtil dictionaryForKey:SAVED_STATE_FIELD_INFLIGHT_PUT_ACCUMULATOR inDictionary:savedState] ?: @{};
        _scheduledPatchCall     = [([WPNSUtil numberForKey:SAVED_STATE_FIELD_SCHEDULED_PATCH_CALL inDictionary:savedState] ?: @NO) boolValue];
        _inflightPatchCall      = [([WPNSUtil numberForKey:SAVED_STATE_FIELD_INFLIGHT_PATCH_CALL inDictionary:savedState] ?: @NO) boolValue];
        
        // Handle state version upgrades (syncStateVersion)
        // - 0 -> 1: No-op. 0 means no previous state.
        // - 1 -> 2: No-op. Only the "upgradeMeta" key has been added and it is read with proper default.

        // Handle client upgrades
        [self applyUpgradeCallback:upgradeCallback];

        if (_inflightPatchCall) {
            [self onFailure];
        }
    }
    return self;
}

- (instancetype) initFromSdkState:(NSDictionary *)sdkState andServerState:(NSDictionary *)serverState saveCallback:(WPJsonSyncSaveCallback)saveCallback serverPatchCallback:(WPJsonSyncServerPatchCallback)serverPatchCallback schedulePatchCallCallback:(WPJsonSyncCallback)schedulePatchCallCallback upgradeCallback:(WPJsonSyncUpgradeCallback)upgradeCallback {
    self = [super init];
    if (self) {
        _serverPatchCallback = serverPatchCallback;
        _saveCallback = saveCallback;
        _schedulePatchCallCallback = schedulePatchCallCallback;

        _upgradeMeta = @{};
        self.sdkState = [WPJsonUtil stripNulls:sdkState ?: @{}];
        self.serverState = [WPJsonUtil stripNulls:serverState ?: @{}];
        _putAccumulator = [WPJsonUtil diff:self.serverState with:self.sdkState];
        _inflightDiff = @{};
        _inflightPutAccumulator = @{};
        _scheduledPatchCall = true;
        _inflightPatchCall = false;

        [self applyUpgradeCallback:upgradeCallback];
    }
    return self;
}

- (void) applyUpgradeCallback:(WPJsonSyncUpgradeCallback)upgradeCallback {
    if (upgradeCallback != nil) {
        NSMutableDictionary *upgradeMeta            = [NSMutableDictionary dictionaryWithDictionary:_upgradeMeta];
        NSMutableDictionary *sdkState               = [NSMutableDictionary dictionaryWithDictionary:self.sdkState];
        NSMutableDictionary *serverState            = [NSMutableDictionary dictionaryWithDictionary:self.serverState];
        NSMutableDictionary *putAccumulator         = [NSMutableDictionary dictionaryWithDictionary:_putAccumulator];
        NSMutableDictionary *inflightDiff           = [NSMutableDictionary dictionaryWithDictionary:_inflightDiff];
        NSMutableDictionary *inflightPutAccumulator = [NSMutableDictionary dictionaryWithDictionary:_inflightPutAccumulator];
        upgradeCallback(upgradeMeta, sdkState, serverState, putAccumulator, inflightDiff, inflightPutAccumulator);
        _upgradeMeta            = [NSDictionary dictionaryWithDictionary:upgradeMeta];
        self.sdkState           = [NSDictionary dictionaryWithDictionary:sdkState];
        self.serverState        = [NSDictionary dictionaryWithDictionary:serverState];
        _putAccumulator         = [NSDictionary dictionaryWithDictionary:putAccumulator];
        _inflightDiff           = [NSDictionary dictionaryWithDictionary:inflightDiff];
        _inflightPutAccumulator = [NSDictionary dictionaryWithDictionary:inflightPutAccumulator];
    }
}

- (void) save {
    @synchronized (self) {
        _saveCallback(@{
                        SAVED_STATE_FIELD__SYNC_STATE_VERSION:      SAVED_STATE_STATE_VERSION_2,
                        SAVED_STATE_FIELD_UPGRADE_META:             _upgradeMeta,
                        SAVED_STATE_FIELD_SDK_STATE:                self.sdkState,
                        SAVED_STATE_FIELD_SERVER_STATE:             self.serverState,
                        SAVED_STATE_FIELD_PUT_ACCUMULATOR:          _putAccumulator,
                        SAVED_STATE_FIELD_INFLIGHT_DIFF:            _inflightDiff ?: @{},
                        SAVED_STATE_FIELD_INFLIGHT_PUT_ACCUMULATOR: _inflightPutAccumulator,
                        SAVED_STATE_FIELD_SCHEDULED_PATCH_CALL:     [NSNumber numberWithBool:_scheduledPatchCall],
                        SAVED_STATE_FIELD_INFLIGHT_PATCH_CALL:      [NSNumber numberWithBool:_inflightPatchCall],
                        });
    }
}

- (void) put:(NSDictionary *)diff {
    @synchronized (self) {
        diff = diff ?: @{};
        self.sdkState = [WPJsonUtil merge:self.sdkState with:diff];
        _putAccumulator = [WPJsonUtil merge:_putAccumulator with:diff nullFieldRemoves:NO];
        [self schedulePatchCallAndSave];
    }
}

- (void) receiveState:(NSDictionary *)state resetSdkState:(bool)reset {
    @synchronized (self) {
        state = state ?: @{};
        self.serverState = [WPJsonUtil stripNulls:[state copy]];
        self.sdkState = [self.serverState copy];
        if (reset) {
            _putAccumulator = @{};
        } else {
            self.sdkState = [WPJsonUtil merge:[WPJsonUtil merge:self.sdkState with:_inflightDiff] with:_putAccumulator];
        }
        [self schedulePatchCallAndSave];
    }
}

- (void) receiveServerState:(NSDictionary *)state {
    @synchronized (self) {
        state = state ?: @{};
        self.serverState = [WPJsonUtil stripNulls:[state copy]];
        [self schedulePatchCallAndSave];
    }
}

- (void) receiveDiff:(NSDictionary *)diff {
    @synchronized (self) {
        diff = diff ?: @{};
        // The diff is already server-side, by contract
        self.serverState = [WPJsonUtil merge:self.serverState with:diff];
        [self put:diff];
    }
}

- (void) schedulePatchCallAndSave {
    @synchronized (self) {
        _scheduledPatchCall = true;
        [self save];
        _schedulePatchCallCallback();
    }
}

- (bool) performScheduledPatchCall {
    @synchronized (self) {
        if (_scheduledPatchCall) {
            [self callPatch];
            return true;
        }
        return false;
    }
}

- (void) callPatch {
    @synchronized (self) {
        if (_inflightPatchCall) {
            if (!_scheduledPatchCall) {
                WPLogDebug(@"Server PATCH call already inflight, scheduling a new one");
                [self schedulePatchCallAndSave];
            } else {
                WPLogDebug(@"Server PATCH call already inflight, and already scheduled");
            }
            [self save];
            return;
        }
        _scheduledPatchCall = false;

        _inflightDiff = [WPJsonUtil diff:self.serverState with:self.sdkState];
        if (_inflightDiff.count == 0) {
            WPLogDebug(@"No diff to send to server");
            [self save];
            return;
        }
        _inflightPatchCall = true;

        _inflightPutAccumulator = [_putAccumulator copy];
        _putAccumulator = @{};

        [self save];
        _serverPatchCallback(_inflightDiff, ^(){[self onSuccess];}, ^(){[self onFailure];});
    }
}

- (void) onSuccess {
    @synchronized (self) {
        _inflightPatchCall = false;
        _inflightPutAccumulator = @{};
        self.serverState = [WPJsonUtil merge:self.serverState with:_inflightDiff];
        _inflightDiff = @{};
        [self save];
    }
}

- (void) onFailure {
    @synchronized (self) {
        _inflightPatchCall = false;
        _putAccumulator = [WPJsonUtil merge:_inflightPutAccumulator with:_putAccumulator nullFieldRemoves:NO];
        _inflightPutAccumulator = @{};
        [self schedulePatchCallAndSave];
    }
}



@end
