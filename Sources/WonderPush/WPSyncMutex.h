//
//  WPSyncMutex.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// A named, non-blocking, cross-thread mutex for the sdk-sync fetch loop (issue .17).
//
// The JS reference uses cross-tab named mutexes with a TTL so a crashed/hung tab eventually frees the
// lock. iOS sync runs in a single process, but a hung or callback-dropping network request would
// otherwise hold the lock for the whole app session and wedge the source — so we keep the TTL: an
// acquisition older than ttlMs is reclaimable by the next tryLock. (Crash-safety across launches is
// separately covered by the persisted lastFetchAttemptedDate guard in the fetch loop.)
//
// `tryLock` is non-blocking (returns 0 instead of waiting) — the fetch loop skips when a fetch for
// the same source is already underway. lock and unlock may run on different threads (the unlock
// happens in an async network completion), so this is NOT built on NSLock (which requires same-thread
// unlock); it uses a short internal guard around a held flag.
//
// `tryLock` returns a per-acquisition TOKEN and `unlock:` only releases when the token matches the
// current holder. This guards against a late/duplicate unlock from one fetch's completion releasing
// a lock a *different* fetch acquired in the meantime — including after a TTL reclaim hands the lock
// to a new holder with a fresh token while the original's callback is still outstanding.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncMutex : NSObject

/// The shared mutex for a given name (same name -> same instance, process-wide).
+ (instancetype)mutexNamed:(NSString *)name;

/// Acquire if free OR if the current hold is older than `ttlMs` (a reclaim). Returns a non-zero token
/// identifying this acquisition, or 0 if held and not yet expired. `ttlMs <= 0` disables reclaim.
/// `now` is the caller's clock in ms (injected for testability).
- (NSUInteger)tryLockAtTime:(long long)now ttlMs:(double)ttlMs;

/// Release iff `token` matches the current holder (the value a prior tryLock returned). Returns YES
/// if released, NO for a stale/duplicate token. Safe to call from a different thread than tryLock.
- (BOOL)unlock:(NSUInteger)token;

@end

NS_ASSUME_NONNULL_END
