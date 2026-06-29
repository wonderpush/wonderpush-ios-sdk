//
//  WPSyncStateStore.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Persistent per-source, per-profile storage for sdk-sync state.
// Ported from the SyncState class in wonderpush-javascript-sdk/src/wonderpush/sync-state.ts.
//
// State is scoped by (source, userId, deviceId): a given SDK instance has a fixed deviceId, so the
// profile is the current userId (nil for the anonymous profile). setUserId switches profiles;
// unsetUserId returns to the anonymous one and reuses its stored state — so we keep non-current
// profiles' state rather than wiping on switch (algorithm.md:19-28).
//
// Backing store mirrors WPConfiguration: a single JSON blob persisted as NSData under one
// NSUserDefaults key. JSON (not a raw NSDictionary) is required because a SyncSourceState carries
// NSNull for its null fields, which NSUserDefaults cannot store directly.

#import <Foundation/Foundation.h>
#import "WPSyncSourceState.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncStateStore : NSObject

/// Backed by [NSUserDefaults standardUserDefaults] — what the rest of the SDK uses.
+ (instancetype)defaultStore;
/// Inject a NSUserDefaults (tests pass an isolated suite).
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Load the state for (source, profile); returns an empty state when nothing is stored.
- (WPSyncSourceState *)loadSource:(NSString *)source
                           userId:(nullable NSString *)userId
                         deviceId:(NSString *)deviceId;

/// Persist the state for (source, profile).
- (void)saveState:(WPSyncSourceState *)state
        forSource:(NSString *)source
           userId:(nullable NSString *)userId
         deviceId:(NSString *)deviceId;

/// The storage key: `sync:<source>:<userId or "">:<deviceId>`.
+ (NSString *)storageKeyForSource:(NSString *)source
                           userId:(nullable NSString *)userId
                         deviceId:(NSString *)deviceId;

@end

NS_ASSUME_NONNULL_END
