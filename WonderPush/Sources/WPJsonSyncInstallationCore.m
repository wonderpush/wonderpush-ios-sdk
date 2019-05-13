#import "WPJsonSyncInstallationCore.h"

#import "WPConfiguration.h"
#import "WonderPush_private.h"
#import "WPLog.h"
#import "WPUtil.h"


static NSMutableDictionary *instancePerUserId = nil;



@interface WPJsonSyncInstallationCore ()


@property (readonly) NSString *userId;
@property NSObject *blockId_lock;
@property int blockId;
@property NSDate *firstDelayedWriteDate;


- (void) save:(NSDictionary *)state;

- (void) scheduleServerPatchCallCallback;

- (void) serverPatchCallbackWithDiff:(NSDictionary *)diff onSuccess:(WPJsonSyncCallback)onSuccess onFailure:(WPJsonSyncCallback)onFailure;

@end



@implementation WPJsonSyncInstallationCore


+ (void) initialize {
    instancePerUserId = [NSMutableDictionary new];
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    @synchronized (instancePerUserId) {
        // Populate entries
        NSDictionary *installationCoreSyncStatePerUserId = conf.installationCoreSyncStatePerUserId ?: @{};
        for (NSString *userId in installationCoreSyncStatePerUserId) {
            NSDictionary *state = [WPUtil dictionaryForKey:userId inDictionary:installationCoreSyncStatePerUserId];
            instancePerUserId[userId ?: @""] = [[WPJsonSyncInstallationCore alloc] initFromSavedState:state userId:userId];
        }
        NSString *oldUserId = conf.userId;
        for (NSString *userId in [[WPConfiguration sharedConfiguration] listKnownUserIds]) {
            if (instancePerUserId[userId ?: @""] == nil) {
                [conf changeUserId:userId];
                instancePerUserId[userId ?: @""] = [[WPJsonSyncInstallationCore alloc] initFromSdkState:conf.cachedInstallationCorePropertiesUpdated andServerState:conf.cachedInstallationCorePropertiesWritten userId:userId];
            }
        }
        [conf changeUserId:oldUserId];
        // Resume any stopped inflight or scheduled calls
        // Adding the listener here will catch the an initial call triggered after this function is called, all during SDK initialization.
        // It also flushes any scheduled call that was dropped when the user withdrew consent.
        [[NSNotificationCenter defaultCenter] addObserverForName:WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED object:nil queue:nil usingBlock:^(NSNotification *notification) {
            BOOL hasUserConsent = [notification.userInfo[WP_NOTIFICATION_HAS_USER_CONSENT_CHANGED_KEY] boolValue];
            if (hasUserConsent) {
                [self flush];
            }
        }];
    }
}

+ (WPJsonSyncInstallationCore *)forCurrentUser {
    return [self forUser:[WPConfiguration sharedConfiguration].userId];
}

+ (WPJsonSyncInstallationCore *)forUser:(NSString *)userId {
    if ([userId length] == 0) userId = nil;
    @synchronized (instancePerUserId) {
        id instance = [instancePerUserId objectForKey:(userId ?: @"")];
        if (![instance isKindOfClass:[WPJsonSync class]]) {
            instance = [[WPJsonSyncInstallationCore alloc] initFromSavedState:@{} userId:userId];
            instancePerUserId[userId ?: @""] = instance;
        }
        return instance;
    }
}

+ (void) flush {
    WPLogDebug(@"Flushing delayed updates of core properties for all known users");
    @synchronized (instancePerUserId) {
        for (NSString *userId in instancePerUserId) {
            id obj = instancePerUserId[userId];
            if ([obj isKindOfClass:[WPJsonSyncInstallationCore class]]) {
                WPJsonSyncInstallationCore *sync = (WPJsonSyncInstallationCore *) obj;
                [sync flush];
            }
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
    NSMutableDictionary *installationCoreSyncStatePerUserId = [(conf.installationCoreSyncStatePerUserId ?: @{}) mutableCopy];
    installationCoreSyncStatePerUserId[_userId ?: @""] = state ?: @{};
    conf.installationCoreSyncStatePerUserId = installationCoreSyncStatePerUserId;
}

- (void) scheduleServerPatchCallCallback {
    WPLogDebug(@"Scheduling a delayed update of core properties");
    if (![WonderPush hasUserConsent]) {
        [WonderPush safeDeferWithConsent:^{
            WPLogDebug(@"Now scheduling user consent delayed patch call for installation core state for userId %@", self.userId);
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
        NSTimeInterval delay = MIN(CACHED_INSTALLATION_CORE_PROPERTIES_MIN_DELAY,
                                   [_firstDelayedWriteDate timeIntervalSinceReferenceDate] + CACHED_INSTALLATION_CORE_PROPERTIES_MAX_DELAY
                                   - [now timeIntervalSinceReferenceDate]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @synchronized (self->_blockId_lock) {
                if (self->_blockId == currentBlockId) {
                    self->_firstDelayedWriteDate = nil;
                    WPLogDebug(@"Performing delayed update of core properties");
                    [self performScheduledPatchCall];
                }
            }
        });
    }
}

- (bool) performScheduledPatchCall
{
    if (![WonderPush hasUserConsent]) {
        WPLogDebug(@"Need consent, not performing scheduled patch call for user %@", self.userId);
        return false;
    }
    return [super performScheduledPatchCall];
}

- (void) serverPatchCallbackWithDiff:(NSDictionary *)diff onSuccess:(WPJsonSyncCallback)onSuccess onFailure:(WPJsonSyncCallback)onFailure {
    WPLogDebug(@"Sending installation core diff: %@ for user %@", diff, _userId);
    [WonderPush requestForUser:_userId
                        method:@"PATCH"
                      resource:@"/installation"
                        params:@{@"body": diff}
                       handler:^(WPResponse *response, NSError *error) {
                           NSDictionary *responseJson = (NSDictionary *)response.object;
                           if (!error && [responseJson isKindOfClass:[NSDictionary class]] && [[WPUtil numberForKey:@"success" inDictionary:responseJson] boolValue]) {
                               WPLogDebug(@"Succeded to send diff for user %@: %@", self->_userId, responseJson);
                               onSuccess();
                           } else {
                               WPLogDebug(@"Failed to send diff for user %@: error %@, response %@", self->_userId, error, response);
                               onFailure();
                           }
                       }];
}

@end
