//
//  WPSyncManager.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// SDK-init lifecycle for the sdk-sync channel (issue .18). Assembles the stack
// (WPSyncStateStore + WPSyncAPITransport + WPSyncFetcher + WPSync + WPSyncContactSource), wires the
// effective knobs from remote config, and installs the WPSync request observer — but ONLY when the
// `syncEnabled` remote-config flag is on (default off), so the whole channel is inert by default and
// the server opts in once integration is verified. WonderPush supplies the identifiers + the request
// `sender` so this manager stays decoupled from the SDK singleton's internals.

#import <Foundation/Foundation.h>
#import "WPSyncAPITransport.h"   // WPSyncAPIRequestSender

@class WPRemoteConfigManager;

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncManager : NSObject

+ (instancetype)sharedManager;

/// Re-evaluate from remote config: refresh the cached knobs, and install (or uninstall) the sync
/// observer per the `syncEnabled` gate. Builds the stack lazily on first enable. Safe to call
/// repeatedly (e.g. on every WPRemoteConfigUpdatedNotification) and before the gate is ever enabled.
- (void)refreshWithRemoteConfigManager:(WPRemoteConfigManager *)remoteConfigManager
                   identifiersProvider:(NSDictionary *(^)(void))identifiersProvider
                                sender:(WPSyncAPIRequestSender)sender;

@end

NS_ASSUME_NONNULL_END
