//
//  WPSyncFetcher.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncFetcher.h"
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"
#import "WPSyncKnobs.h"
#import "WPSyncFetchPolicy.h"
#import "WPSyncMutex.h"

@interface WPSyncFetcher ()
@property (nonatomic, strong) WPSyncStateStore *stateStore;
@property (nonatomic, strong) id<WPSyncFetchTransport> transport;
@end

@implementation WPSyncFetcher

- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore transport:(id<WPSyncFetchTransport>)transport {
    if (self = [super init]) {
        _stateStore = stateStore;
        _transport = transport;
        _nowProvider = ^long long{ return (long long)([[NSDate date] timeIntervalSince1970] * 1000.0); };
        _scheduler = ^(double delayMs, dispatch_block_t block) {
            if (delayMs <= 0) { block(); return; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayMs * NSEC_PER_MSEC)),
                           dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
        };
        _randomProvider = ^double{ return (double)arc4random() / ((double)UINT32_MAX + 1.0); };
    }
    return self;
}

- (void)fetchSource:(NSString *)source
             userId:(NSString *)userId
           deviceId:(NSString *)deviceId
        identifiers:(NSDictionary *)identifiers
              knobs:(WPSyncKnobs *)knobs
               weak:(BOOL)weak
               hint:(WPSyncFetchHint *)hint
         completion:(void (^)(BOOL attempted))completion {
    void (^done)(BOOL) = ^(BOOL attempted) { if (completion) completion(attempted); };

    NSString *path = WPSyncExplicitPathForSource(source);
    if (path == nil) { done(NO); return; }   // unknown source

    WPSyncSourceState *state = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
    long long now = self.nowProvider();

    // Step 1: guards. Weak signals are debounced; ALL triggers are subject to the rate-limit floor.
    if (weak && [WPSyncFetchPolicy shouldDebounceWeakSignalAtNow:now
                                       lastFetchAttemptedDate:state.lastFetchAttemptedDate
                                                   debounceMs:knobs.weakSyncSignalDebounceMs]) {
        done(NO); return;
    }
    if ([WPSyncFetchPolicy shouldRateLimitSourceAtNow:now
                               lastFetchAttemptedDate:state.lastFetchAttemptedDate
                                        minIntervalMs:knobs.minSourceFetchIntervalMs]) {
        done(NO); return;
    }

    // Step 2: acquire the per-source fetch mutex (non-blocking — skip if already in flight).
    WPSyncMutex *mutex = [WPSyncMutex mutexNamed:[@"sync:" stringByAppendingString:source]];
    NSUInteger token = [mutex tryLock];
    if (token == 0) { done(NO); return; }

    // Step 3: stamp the attempt + compute backoff + bump the failure count, persisted BEFORE the call.
    double sleepMs = [WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:state.lastFetchUnsuccessfulAttemptCount
                                                                       rand:self.randomProvider()
                                                                      knobs:knobs];
    state.lastFetchAttemptedDate = now;
    state.lastFetchUnsuccessfulAttemptCount += 1;
    [self.stateStore saveState:state forSource:source userId:userId deviceId:deviceId];

    NSDictionary *params = [WPSyncFetchPolicy buildExplicitFetchParamsWithIdentifiers:identifiers state:state hint:hint];

    __weak WPSyncFetcher *weakSelf = self;
    // Step 4: backoff sleep, then Step 5: the GET.
    self.scheduler(sleepMs, ^{
        WPSyncFetcher *self2 = weakSelf;
        if (!self2) { [mutex unlock:token]; done(YES); return; }
        [self2.transport fetchSource:source path:path params:params completion:^(BOOL success) {
            // Step 6: on success reset the failure count (re-load: the response interceptor may have
            // advanced lastVersion/lastReadDate). On failure leave the count (longer next backoff).
            if (success) {
                WPSyncSourceState *latest = [self2.stateStore loadSource:source userId:userId deviceId:deviceId];
                latest.lastFetchUnsuccessfulAttemptCount = 0;
                [self2.stateStore saveState:latest forSource:source userId:userId deviceId:deviceId];
            }
            // Step 7: always release the mutex (token-matched, so a stale release is impossible).
            [mutex unlock:token];
            done(YES);
        }];
    });
}

@end
