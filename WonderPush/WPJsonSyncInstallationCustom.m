#import "WPJsonSyncInstallationCustom.h"

#import "WPConfiguration.h"
#import "WonderPush_private.h"
#import "WPLog.h"



static NSMutableDictionary *instancePerUserId = nil;



@interface WPJsonSyncInstallationCustom ()


@property (readonly) NSString *userId;
@property NSObject *blockId_lock;
@property int blockId;
@property NSDate *firstDelayedWriteDate;


- (void) save:(NSDictionary *)state;

- (void) scheduleServerPatchCallCallback;

- (void) serverPatchCallbackWithDiff:(NSDictionary *)diff onSuccess:(WPJsonSyncCallback)onSuccess onFailure:(WPJsonSyncCallback)onFailure;

@end



@implementation WPJsonSyncInstallationCustom


+ (void) initialize {
    instancePerUserId = [NSMutableDictionary new];
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    @synchronized (instancePerUserId) {
        // Populate entries
        NSDictionary *installationCustomSyncStatePerUserId = conf.installationCustomSyncStatePerUserId ?: @{};
        for (NSString *userId in installationCustomSyncStatePerUserId) {
            NSDictionary *state = [installationCustomSyncStatePerUserId dictionaryForKey:userId];
            instancePerUserId[userId ?: @""] = [[WPJsonSyncInstallationCustom alloc] initFromSavedState:state userId:userId];
        }
        NSString *oldUserId = conf.userId;
        for (NSString *userId in [[WPConfiguration sharedConfiguration] listKnownUserIds]) {
            if (instancePerUserId[userId ?: @""] == nil) {
                [conf changeUserId:userId];
                instancePerUserId[userId ?: @""] = [[WPJsonSyncInstallationCustom alloc] initFromSdkState:conf.cachedInstallationCustomPropertiesUpdated andServerState:conf.cachedInstallationCustomPropertiesWritten userId:userId];
            }
        }
        [conf changeUserId:oldUserId];
        // Resume any stopped inflight or scheduled calls
        [self flush];
    }
}

+ (WPJsonSyncInstallationCustom *)forCurrentUser {
    return [self forUser:[WPConfiguration sharedConfiguration].userId];
}

+ (WPJsonSyncInstallationCustom *)forUser:(NSString *)userId {
    if ([userId length] == 0) userId = nil;
    @synchronized (instancePerUserId) {
        id instance = [instancePerUserId objectForKey:(userId ?: @"")];
        if (![instance isKindOfClass:[WPJsonSync class]]) {
            instance = [[WPJsonSyncInstallationCustom alloc] initFromSavedState:@{} userId:userId];
            instancePerUserId[userId ?: @""] = instance;
        }
        return instance;
    }
}

+ (void) flush {
    WPLogDebug(@"Flushing delayed updates of custom properties for all known users");
    for (NSString *userId in instancePerUserId) {
        id obj = instancePerUserId[userId];
        if ([obj isKindOfClass:[WPJsonSyncInstallationCustom class]]) {
            WPJsonSyncInstallationCustom *sync = (WPJsonSyncInstallationCustom *) obj;
            [sync flush];
        }
    }
}


- (void) init_commonWithUserId:(NSString *)userId {
    if (![userId length]) userId = nil;
    _userId = userId;
    _blockId_lock = [NSObject new];
    _blockId = 0;
}

- (instancetype) initFromSavedState:(NSDictionary *)state userId:(NSString *)userId {
    self = [super initFromSavedState:state
                        saveCallback:^(NSDictionary *state) {
                            [self save:state];
                        }
                 serverPatchCallback:^(NSDictionary *diff, WPJsonSyncCallback onSuccess, WPJsonSyncCallback onFailure) {
                     [self serverPatchCallbackWithDiff:diff onSuccess:onSuccess onFailure:onFailure];
                 }
           schedulePatchCallCallback:^{
               [self scheduleServerPatchCallCallback];
           }];
    if (self) {
        [self init_commonWithUserId:userId];
    }
    return self;
}

- (instancetype) initFromSdkState:(NSDictionary *)sdkState andServerState:(NSDictionary *)serverState userId:(NSString *)userId {
    self = [super initFromSdkState:sdkState
                    andServerState:serverState
                      saveCallback:^(NSDictionary *state) {
                          [self save:state];
                      }
               serverPatchCallback:^(NSDictionary *diff, WPJsonSyncCallback onSuccess, WPJsonSyncCallback onFailure) {
                   [self serverPatchCallbackWithDiff:diff onSuccess:onSuccess onFailure:onFailure];
               }
         schedulePatchCallCallback:^{
             [self scheduleServerPatchCallCallback];
         }];
    if (self) {
        [self init_commonWithUserId:userId];
    }
    return self;
}

- (void) flush {
    @synchronized (_blockId_lock) {
        // Prevent any block from running
        _blockId++;
    }
    [self performScheduledPatchCall];
}

- (void) save:(NSDictionary *)state {
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    NSMutableDictionary *installationCustomSyncStatePerUserId = [(conf.installationCustomSyncStatePerUserId ?: @{}) mutableCopy];
    installationCustomSyncStatePerUserId[_userId ?: @""] = state ?: @{};
    conf.installationCustomSyncStatePerUserId = installationCustomSyncStatePerUserId;
}

- (void) scheduleServerPatchCallCallback {
    WPLogDebug(@"Scheduling a delayed update of custom properties");
    @synchronized (_blockId_lock) {
        int currentBlockId = ++_blockId;
        NSDate *now = [NSDate date];
        if (!_firstDelayedWriteDate) {
            _firstDelayedWriteDate = now;
        }
        NSTimeInterval delay = MIN(CACHED_INSTALLATION_CUSTOM_PROPERTIES_MIN_DELAY,
                                   [_firstDelayedWriteDate timeIntervalSinceReferenceDate] + CACHED_INSTALLATION_CUSTOM_PROPERTIES_MAX_DELAY
                                   - [now timeIntervalSinceReferenceDate]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @synchronized (_blockId_lock) {
                if (_blockId == currentBlockId) {
                    _firstDelayedWriteDate = nil;
                    WPLogDebug(@"Performing delayed update of custom properties");
                    [self performScheduledPatchCall];
                }
            }
        });
    }
}

- (void) serverPatchCallbackWithDiff:(NSDictionary *)diff onSuccess:(WPJsonSyncCallback)onSuccess onFailure:(WPJsonSyncCallback)onFailure {
    WPLogDebug(@"Sending installation custom diff: %@ for user %@", diff, _userId);
    [WonderPush requestForUser:_userId
                        method:@"PATCH"
                      resource:@"/installation"
              params:@{@"body": @{@"custom": diff}}
             handler:^(WPResponse *response, NSError *error) {
                 NSDictionary *responseJson = (NSDictionary *)response.object;
                 if (!error && [responseJson isKindOfClass:[NSDictionary class]] && [[responseJson numberForKey:@"success"] boolValue]) {
                     WPLogDebug(@"Succeded to send diff for user %@: %@", _userId, responseJson);
                     onSuccess();
                 } else {
                     WPLogDebug(@"Failed to send diff for user %@: error %@, response %@", error, response);
                     onFailure();
                 }
             }];
}

@end
