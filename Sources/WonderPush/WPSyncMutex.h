//
//  WPSyncMutex.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// A named, non-blocking, cross-thread mutex for the sdk-sync fetch loop (issue .17).
//
// The JS reference uses cross-tab named mutexes with a TTL so a crashed tab eventually frees the
// lock. iOS sync runs in a single process, so a crash resets all in-memory locks — no TTL is needed;
// crash-safety across launches is provided separately by the persisted lastFetchAttemptedDate guard
// in the fetch loop. This primitive is just: at most one holder per name at a time.
//
// `tryLock` is non-blocking (returns NO instead of waiting) — the fetch loop skips when a fetch for
// the same source is already underway. lock and unlock may run on different threads (the unlock
// happens in an async network completion), so this is NOT built on NSLock (which requires same-thread
// unlock); it uses a short internal guard around a held flag.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncMutex : NSObject

/// The shared mutex for a given name (same name -> same instance, process-wide).
+ (instancetype)mutexNamed:(NSString *)name;

/// Acquire if free. Returns YES and marks held; returns NO if already held (caller should skip).
- (BOOL)tryLock;

/// Release. Safe to call from a different thread than tryLock. No-op if not held.
- (void)unlock;

@end

NS_ASSUME_NONNULL_END
