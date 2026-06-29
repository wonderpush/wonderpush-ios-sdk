//
//  WPSyncSourceState.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Per-source persistent state for the sdk-sync channel.
// Ported from the JS reference SDK: wonderpush-javascript-sdk/src/wonderpush/sync-state.ts.
// Field semantics: sdk-sync/docs/docs/sync/algorithm.md:30-33 (stored state) and :87-91
// (the five fields echoed to the server on every opportunistic call).
//
// A "VersionId" is the JS `number | string | null` union. In Objective-C we carry it as `id`:
//   - NSNumber  -> int64 version id
//   - NSString  -> string version id
//   - nil       -> the "null-missing" sentinel
// `lastSyncMeta` is OPAQUE (algorithm.md:339): we store and echo it, never inspect it.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncSourceState : NSObject <NSCopying>

/// Last _serverTime at which the SDK was given affirmative information.
@property (nonatomic, assign) long long lastSyncDate;
/// Opaque blob handed back to the server on every call (nil == JS null).
@property (nonatomic, strong, nullable) NSDictionary *lastSyncMeta;
/// Update date of the most recently updated object (its version).
@property (nonatomic, assign) long long lastVersion;
/// Id of the most recently updated object: NSNumber | NSString | nil (null-missing).
@property (nonatomic, strong, nullable) id lastVersionId;
/// Last date the information was read from the underlying storage.
@property (nonatomic, assign) long long lastReadDate;
/// Local: last time an explicit fetch was attempted.
@property (nonatomic, assign) long long lastFetchAttemptedDate;
/// Local: consecutive failures, drives exponential backoff.
@property (nonatomic, assign) NSInteger lastFetchUnsuccessfulAttemptCount;
/// Source-owned payload: NSDictionary (single-object), NSArray (multi-object), or nil.
@property (nonatomic, strong, nullable) id data;

/// The empty state: all zeros / nils, matching emptyState() in sync-state.ts.
+ (instancetype)emptyState;

/// Round-trips with the JSON shape persisted on disk and used by the conformance vectors.
/// Missing keys and JSON null map to the empty-state default for that field.
+ (instancetype)stateWithDictionary:(nullable NSDictionary *)dict;
- (NSDictionary *)toDictionary;

/// Write this state's outbound wire params into `params`, each key prefixed by `prefix`:
/// always the int64 trio (lastSyncDate/lastVersion/lastReadDate); lastSyncMeta JSON-encoded and
/// lastVersionId only when set. Used by both opportunistic injection (prefix @"_<source>Sync.") and
/// explicit fetch (prefix @""), so the field->param mapping lives in one place.
- (void)writeWireParamsWithPrefix:(NSString *)prefix into:(NSMutableDictionary *)params;

@end

NS_ASSUME_NONNULL_END
