//
//  WPSyncFetcher.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The explicit-fetch loop for the sdk-sync channel (issue .16). Ported from the Sync.fetch /
// runFetchWithMutexHeld logic in wonderpush-javascript-sdk/src/wonderpush/sync.js (algorithm.md:245-257):
//
//   1. weak-signal debounce + per-source rate-limit guards (skip if too soon),
//   2. acquire the per-source mutex (skip if a fetch is already in flight),
//   3. stamp lastFetchAttemptedDate + increment the failure count + persist BEFORE the call
//      (so a crash mid-flight still records the attempt for backoff),
//   4. exponential-backoff sleep,
//   5. issue the GET (the response is processed by the incoming interceptor, issue .15),
//   6. on success reset the failure count; on failure leave it (longer next backoff),
//   7. always release the mutex.
//
// The network and the clock are injected (WPSyncFetchTransport + the block properties below) so the
// loop's timing/locking/bookkeeping is unit-testable without real I/O or real delays. The orchestrator
// (issue .18) supplies the real transport (a GET via WPAPIClient) and the effective knobs/identifiers.
//
// NOTE: multi-object paging continuations (block-acquire of the mutex; bd ki1) are out of scope here
// and land with the popups/inbox sources (.23/.24).

#import <Foundation/Foundation.h>

@class WPSyncStateStore, WPSyncKnobs, WPSyncFetchHint;

NS_ASSUME_NONNULL_BEGIN

/// Performs the actual GET. `success` reflects the HTTP outcome (the response body is consumed by
/// the incoming interceptor separately). Completion may run on any thread.
@protocol WPSyncFetchTransport <NSObject>
- (void)fetchSource:(NSString *)source
               path:(NSString *)path
             params:(NSDictionary *)params
         completion:(void (^)(BOOL success))completion;
@end

@interface WPSyncFetcher : NSObject

- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore
                         transport:(id<WPSyncFetchTransport>)transport NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Current time in ms. Default: real wall clock. Overridable in tests.
@property (nonatomic, copy) long long (^nowProvider)(void);
/// Run `block` after `delayMs`. Default: dispatch_after on a background queue. Overridable in tests.
@property (nonatomic, copy) void (^scheduler)(double delayMs, dispatch_block_t block);
/// A [0,1) value for backoff jitter. Default: arc4random-based. Overridable in tests.
@property (nonatomic, copy) double (^randomProvider)(void);

/// Trigger an explicit fetch for `source` scoped to (userId, deviceId).
/// `identifiers` carries deviceId/installationId/visitorId for the request params (NOT userId).
/// `weak` marks a weak-signal trigger (subject to debounce). `hint` echoes head-hint fields.
/// `completion` reports whether the fetch was actually attempted (NO = skipped by a guard/mutex).
- (void)fetchSource:(NSString *)source
             userId:(nullable NSString *)userId
           deviceId:(NSString *)deviceId
        identifiers:(NSDictionary *)identifiers
              knobs:(WPSyncKnobs *)knobs
               weak:(BOOL)weak
               hint:(nullable WPSyncFetchHint *)hint
         completion:(nullable void (^)(BOOL attempted))completion;

@end

NS_ASSUME_NONNULL_END
