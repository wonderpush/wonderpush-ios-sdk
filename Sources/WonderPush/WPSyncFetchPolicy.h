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

/// Coalesce a freshly-received `syncAfterTime` hint (CP-56 — "Late identifier resolution") into the
/// due date the SDK should schedule its one extra explicit sync for.
///
/// The server re-emits the hint on every opportunistic call until the explicit call lands (expected,
/// not a bug) — so repeated hints must coalesce to the EARLIEST due time already scheduled, never
/// pushed later by a subsequent hint. If nothing is scheduled yet (`existingDueDate` is 0), or the
/// existing due date has already passed, the fresh hint wins.
+ (long long)coalesceSyncAfterTimeDueDateAtNow:(long long)now
                                       delayMs:(double)delayMs
                               existingDueDate:(long long)existingDueDate;

/// Query params for an explicit fetch (algorithm.md:271-279): the 3 non-userId identifiers + the
/// source's sync state at the top level (no `_<source>Sync.` prefix). `userId` is added elsewhere.
/// `lastSyncMeta` is JSON-encoded; `lastSyncMeta`/`lastVersionId` omitted when nil. When `hint` is
/// given, its present known* fields are echoed back.
+ (NSDictionary *)buildExplicitFetchParamsWithIdentifiers:(NSDictionary *)identifiers
                                                    state:(WPSyncSourceState *)state
                                                     hint:(nullable WPSyncFetchHint *)hint;

@end

NS_ASSUME_NONNULL_END
