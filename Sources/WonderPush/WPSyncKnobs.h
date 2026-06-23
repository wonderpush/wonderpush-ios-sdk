//
//  WPSyncKnobs.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The canonical knob set for the sdk-sync channel.
// Ported from the JS reference SDK: wonderpush-javascript-sdk/src/wonderpush/sync-knobs.ts (the
// SyncKnobs interface). Spec-tunable parameters: sdk-sync/docs/docs/sync/algorithm.md:349-355.
//
// This type only carries the values. The default values (DEFAULT_KNOBS), the remote-config merge
// (mergeKnobs) and the staleness predicate (isStateStale) are ported separately (issue .7).
//
// Age caps default to +Infinity (no forcing), so those fields are `double` to hold INFINITY.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncKnobs : NSObject <NSCopying>

/// WEAK_SYNC_SIGNAL_DEBOUNCE: minimum delay since last fetch for a weak-signal-triggered fetch.
@property (nonatomic, assign) double weakSyncSignalDebounceMs;
/// Forces a fetch when lastSyncDate is older than this (may be INFINITY == no forcing).
@property (nonatomic, assign) double maxLastSyncDateAgeMs;
/// Forces a fetch when lastReadDate is older than this (may be INFINITY == no forcing).
@property (nonatomic, assign) double maxLastReadDateAgeMs;
/// Cap on stored popup items.
@property (nonatomic, assign) NSInteger maxPopupsEntries;
/// Cap on stored inbox items.
@property (nonatomic, assign) NSInteger maxInboxEntries;

/// Exponential-backoff base (ms).
@property (nonatomic, assign) double exponentialBackoffMinMs;
/// Exponential-backoff cap (ms).
@property (nonatomic, assign) double exponentialBackoffMaxMs;
/// Exponential-backoff growth ratio.
@property (nonatomic, assign) double exponentialBackoffRatio;
/// Exponential-backoff jitter ratio.
@property (nonatomic, assign) double exponentialBackoffJitterRatio;

/// Mutex liveness TTL (ms).
@property (nonatomic, assign) double mutexTtlMs;
/// Opportunistic-injection kill switch.
@property (nonatomic, assign) BOOL opportunisticInjectionEnabled;
/// Per-source floor between explicit-fetch attempts (ms); 0 disables.
@property (nonatomic, assign) double minSourceFetchIntervalMs;

/// Round-trips with the JSON shape used by default-knobs.json and the conformance vectors
/// (the SyncKnobs field names; INFINITY must already be mapped from the "Infinity" sentinel).
+ (instancetype)knobsWithDictionary:(nullable NSDictionary *)dict;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
