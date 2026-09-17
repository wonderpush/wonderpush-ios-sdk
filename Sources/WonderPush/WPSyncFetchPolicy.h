//
//  WPSyncFetchPolicy.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Pure helpers for the sdk-sync explicit fetch loop (algorithm.md:245-257).
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-fetch.ts. No Mutex / Storage / Rest —
// the timing math, debounce/rate-limit decisions and request-param construction are all testable
// in isolation; the orchestrator (issue .18) wires them to the real fetch loop.

#import <Foundation/Foundation.h>

@class WPSyncKnobs;
@class WPSyncSourceState;
@class WPSyncFetchHint;

NS_ASSUME_NONNULL_BEGIN

/// Source name -> explicit endpoint path (no `/v1` prefix; Rest prepends the version segment).
FOUNDATION_EXPORT NSString * _Nullable WPSyncExplicitPathForSource(NSString *source);

@interface WPSyncFetchPolicy : NSObject

/// Abort a weak-signal (knownReadDate-only) fetch if still inside the debounce window. Firm signals
/// are not subject to this. True when a fetch was attempted < debounceMs ago.
+ (BOOL)shouldDebounceWeakSignalAtNow:(long long)now
                lastFetchAttemptedDate:(long long)lastFetchAttemptedDate
                            debounceMs:(double)debounceMs;

/// Per-source rate-limit floor applied to EVERY trigger (firm/weak/max-age). True when a fetch was
/// attempted < minIntervalMs ago. Disabled when minIntervalMs <= 0; never fires before the first fetch.
+ (BOOL)shouldRateLimitSourceAtNow:(long long)now
            lastFetchAttemptedDate:(long long)lastFetchAttemptedDate
                     minIntervalMs:(double)minIntervalMs;

/// Backoff sleep (ms) before the next attempt: MIN(MAX, MIN * RATIO^count) * (1 + rand * JITTER).
/// attemptCount <= 0 returns 0 (first attempt, no backoff). Reads the 4 backoff knobs.
+ (double)computeBackoffSleepWithAttemptCount:(NSInteger)attemptCount
                                         rand:(double)rand
                                        knobs:(WPSyncKnobs *)knobs;

/// Query params for an explicit fetch (algorithm.md:271-279): the 3 non-userId identifiers + the
/// source's sync state at the top level (no `_<source>Sync.` prefix). `userId` is added elsewhere.
/// `lastSyncMeta` is JSON-encoded; `lastSyncMeta`/`lastVersionId` omitted when nil. When `hint` is
/// given, its present known* fields are echoed back.
+ (NSDictionary *)buildExplicitFetchParamsWithIdentifiers:(NSDictionary *)identifiers
                                                    state:(WPSyncSourceState *)state
                                                     hint:(nullable WPSyncFetchHint *)hint;

@end

NS_ASSUME_NONNULL_END
