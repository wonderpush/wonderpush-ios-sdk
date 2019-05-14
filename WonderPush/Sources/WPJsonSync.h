#ifndef WPJsonSync_h
#define WPJsonSync_h

#import <Foundation/Foundation.h>



typedef void (^WPJsonSyncCallback)(void);
typedef void (^WPJsonSyncSaveCallback)(NSDictionary *state);
typedef void (^WPJsonSyncServerPatchCallback)(NSDictionary *diff, WPJsonSyncCallback onSuccess, WPJsonSyncCallback onFailure);
typedef NSDictionary *(^WPJsonSyncUpgradeDictCallback)(NSDictionary *upgradeMeta, NSDictionary *inputDict);
typedef NSDictionary *(^WPJsonSyncUpgradeMetaCallback)(NSDictionary *upgradeMeta);



@interface WPJsonSync : NSObject


@property (readonly, copy) NSDictionary *sdkState;
@property (readonly, copy) NSDictionary *serverState;
@property (readonly) bool scheduledPatchCall;
@property (readonly) bool inflightPatchCall;


- (instancetype) initFromSavedState:(NSDictionary *)savedState saveCallback:(WPJsonSyncSaveCallback)saveCallback serverPatchCallback:(WPJsonSyncServerPatchCallback)serverPatchCallback schedulePatchCallCallback:(WPJsonSyncCallback)schedulePatchCallCallback upgradeDictCallback:(WPJsonSyncUpgradeDictCallback)upgradeDictCallback upgradeMetaCallback:(WPJsonSyncUpgradeMetaCallback)upgradeMetaCallback;
- (instancetype) initFromSdkState:(NSDictionary *)sdkState andServerState:(NSDictionary *)serverState saveCallback:(WPJsonSyncSaveCallback)saveCallback serverPatchCallback:(WPJsonSyncServerPatchCallback)serverPatchCallback schedulePatchCallCallback:(WPJsonSyncCallback)schedulePatchCallCallback;


- (void) put:(NSDictionary *)diff;
- (void) receiveState:(NSDictionary *)state resetSdkState:(bool)reset;
- (void) receiveServerState:(NSDictionary *)state;
- (void) receiveDiff:(NSDictionary *)diff;

- (bool) performScheduledPatchCall;


@end



#endif /* WPJsonSync_h */
