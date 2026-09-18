//
//  WPSync.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSync.h"
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"
#import "WPSyncKnobs.h"
#import "WPSyncOutgoing.h"
#import "WPSyncProcessor.h"
#import "WPSyncResponseBlock.h"
#import "WPSyncDecision.h"
#import "WPSyncFetcher.h"   // WPSyncFetching
#import "WPSyncFetchPolicy.h"
#import <WonderPushCommon/WPLog.h>
#import <math.h>

NSString * const WPSyncSourceDataDidChangeNotification = @"WPSyncSourceDataDidChangeNotification";

@interface WPSync ()
@property (nonatomic, strong) WPSyncStateStore *stateStore;
@property (nonatomic, strong) id<WPSyncFetching> fetcher;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *sources;          // name -> plugin or NSNull
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSObject *> *procLocks; // name -> per-source lock
@property (nonatomic, strong) NSLock *registryLock;
// Live cancellable handles for the CP-56 "Late identifier resolution" syncAfterTime scheduling, keyed
// by source name. Kept OUT of WPSyncSourceState: a live timer handle isn't persistable, only the due
// date is (state.syncAfterTimeDueDate). Protected by registryLock.
@property (nonatomic, strong) NSMutableDictionary<NSString *, dispatch_block_t> *syncAfterTimeTimers;
@end

@implementation WPSync

- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore fetcher:(id<WPSyncFetching>)fetcher {
    if (self = [super init]) {
        _stateStore = stateStore;
        _fetcher = fetcher;
        _sources = [NSMutableDictionary new];
        _procLocks = [NSMutableDictionary new];
        _registryLock = [NSLock new];
        _syncAfterTimeTimers = [NSMutableDictionary new];
        _identifiersProvider = ^NSDictionary *{ return @{}; };
        _knobsProvider = ^WPSyncKnobs *{ return [WPSyncKnobs defaultKnobs]; };
        _nowProvider = ^long long{ return (long long)([[NSDate date] timeIntervalSince1970] * 1000.0); };
        _scheduler = ^(double delayMs, dispatch_block_t block) {
            if (delayMs <= 0) { block(); return; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayMs * NSEC_PER_MSEC)),
                           dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
        };
    }
    return self;
}

#pragma mark - registry

- (void)registerSource:(NSString *)name plugin:(id<WPSyncSourcePlugin>)plugin {
    [self.registryLock lock];
    self.sources[name] = plugin ?: (id)[NSNull null];
    if (!self.procLocks[name]) self.procLocks[name] = [NSObject new];
    [self.registryLock unlock];

    // Rearm any syncAfterTime due date persisted from a previous session (CP-56 — "Late identifier
    // resolution" must not lose the one scheduled extra explicit sync across app restarts).
    // Best-effort: a missing deviceId at this point just means sync is a no-op for now.
    @try {
        NSDictionary *ids = [self currentValidIdentifiers];
        if (ids == nil) return;
        NSString *userId = ids[@"userId"], *deviceId = ids[@"deviceId"];
        WPSyncSourceState *state = [self.stateStore loadSource:name userId:userId deviceId:deviceId];
        if (state.syncAfterTimeDueDate > 0) {
            [self armSyncAfterTimeTimerForSource:name dueDate:state.syncAfterTimeDueDate
                                      identifiers:ids userId:userId deviceId:deviceId];
        }
    } @catch (NSException *e) {
        WPLog(@"WPSync: registerSource syncAfterTime rearm failed for %@: %@", name, e);
    }
}

- (NSArray<NSString *> *)registeredSources {
    [self.registryLock lock];
    NSArray *names = [self.sources.allKeys copy];
    [self.registryLock unlock];
    return names;
}

- (NSObject *)procLockForSource:(NSString *)source {
    [self.registryLock lock];
    NSObject *lock = self.procLocks[source];
    if (!lock) { lock = [NSObject new]; self.procLocks[source] = lock; }
    [self.registryLock unlock];
    return lock;
}

- (nullable id<WPSyncSourcePlugin>)pluginForSource:(NSString *)source {
    [self.registryLock lock];
    id plugin = self.sources[source];
    [self.registryLock unlock];
    return (plugin == [NSNull null]) ? nil : plugin;
}

#pragma mark - helpers

/// Effective knobs, failing open to defaults (a nil provider result must not read 0.0 age caps and
/// turn into a fetch storm — mirrors the JS getKnobs fail-open).
- (WPSyncKnobs *)effectiveKnobs {
    return self.knobsProvider() ?: [WPSyncKnobs defaultKnobs];
}

/// The current identifiers, or nil when there's no usable deviceId yet (the deviceId invariant —
/// deviceId is established at SDK init; before then sync is a no-op). Centralizes the guard.
- (nullable NSDictionary *)currentValidIdentifiers {
    NSDictionary *ids = self.identifiersProvider() ?: @{};
    NSString *deviceId = ids[@"deviceId"];
    return ([deviceId isKindOfClass:[NSString class]] && deviceId.length > 0) ? ids : nil;
}

#pragma mark - outgoing

- (NSDictionary *)prepareOutgoingParamsForPath:(NSString *)path method:(NSString *)method {
    @try {
        if (![WPSyncOutgoing shouldInjectForPath:path method:method]) {
            WPLogDebug(@"WPSync: not injecting for path=%@ method=%@ (not classified opportunistic)", path, method);
            return @{};
        }
        if (![self effectiveKnobs].opportunisticInjectionEnabled) {
            WPLogDebug(@"WPSync: not injecting for path=%@ method=%@ (opportunisticInjectionEnabled=NO)", path, method);
            return @{};
        }
        NSDictionary *ids = [self currentValidIdentifiers];
        if (ids == nil) {
            WPLogDebug(@"WPSync: not injecting for path=%@ method=%@ (no usable deviceId yet; identifiersProvider returned %@)", path, method, self.identifiersProvider());
            return @{};
        }
        NSString *userId = ids[@"userId"], *deviceId = ids[@"deviceId"];
        NSMutableDictionary<NSString *, WPSyncSourceState *> *statePerSource = [NSMutableDictionary new];
        for (NSString *source in [self registeredSources]) {
            statePerSource[source] = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
        }
        NSDictionary *result = [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:ids statePerSource:statePerSource];
        WPLogDebug(@"WPSync: injecting %lu params for path=%@ method=%@ (ids=%@): %@", (unsigned long)result.count, path, method, ids, result);
        return result;
    } @catch (NSException *e) {
        WPLog(@"WPSync: prepareOutgoingParams failed, skipping injection: %@", e);
        return @{};   // best-effort: never break the host request
    }
}

#pragma mark - incoming

- (void)consumeIncomingResponseForPath:(NSString *)path method:(NSString *)method response:(NSDictionary *)response {
    @try {
        if (![response isKindOfClass:[NSDictionary class]]) return;
        WPSyncResponseClassification *c = [WPSyncProcessor classifyResponsePath:path method:method];
        if ([c.mode isEqualToString:@"none"]) return;
        NSDictionary *ids = [self currentValidIdentifiers];
        if (ids == nil) return;
        NSString *userId = ids[@"userId"], *deviceId = ids[@"deviceId"];
        NSNumber *serverTime = [response[@"_serverTime"] isKindOfClass:[NSNumber class]] ? response[@"_serverTime"] : nil;

        if ([c.mode isEqualToString:@"opportunistic"]) {
            // Iterate ALL registered sources (the processor handles a missing block correctly).
            for (NSString *source in [self registeredSources]) {
                id block = response[[NSString stringWithFormat:@"_%@Sync", source]];
                [self processSource:source blockDict:block serverTime:serverTime ids:ids userId:userId deviceId:deviceId mode:@"opportunistic"];
            }
        } else if (c.explicitSource) {
            // The response root IS the block; WPSyncResponseBlock reads only recognized keys (ignores _serverTime etc.).
            [self processSource:c.explicitSource blockDict:response serverTime:serverTime ids:ids userId:userId deviceId:deviceId mode:@"explicit"];
        }
        [self checkMaxAgeForcingWithIdentifiers:ids userId:userId deviceId:deviceId];
    } @catch (NSException *e) {
        WPLog(@"WPSync: consumeIncomingResponse failed: %@", e);   // best-effort: never break the host callback chain
    }
}

/// Serialized per source: load -> process -> apply (save + data) under the per-source lock. The fetch
/// trigger fires AFTER releasing the lock — a synchronous transport completion would otherwise
/// re-enter this same (recursive) lock and nest the read-modify-write on partially-applied state.
- (void)processSource:(NSString *)source blockDict:(id)blockDict serverTime:(NSNumber *)serverTime
                  ids:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId mode:(NSString *)mode {
    WPSyncDecision *decision;
    @synchronized ([self procLockForSource:source]) {
        WPSyncSourceState *state = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
        WPSyncResponseBlock *block = [blockDict isKindOfClass:[NSDictionary class]]
            ? [WPSyncResponseBlock blockWithDictionary:blockDict] : nil;
        decision = [WPSyncProcessor processSourceBlock:block serverTime:serverTime state:state mode:mode];
        [self applyDecision:decision source:source userId:userId deviceId:deviceId];
    }
    // Notify consumers (the in-app engine) that this source's DATA changed, AFTER releasing the lock.
    BOOL dataChanged = decision.nextState != nil
        && (decision.hasApplyData || decision.hasApplyDelta || decision.clearState);
    if (dataChanged) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WPSyncSourceDataDidChangeNotification
                                                            object:self userInfo:@{@"source": source}];
    }
    if (decision.triggerFetch != nil) {
        // Fire-and-forget, outside the lock; forward the head hint so the explicit request echoes known*.
        [self.fetcher fetchSource:source userId:userId deviceId:deviceId identifiers:ids
                            knobs:[self effectiveKnobs]
                             weak:[decision.triggerFetch isEqualToString:@"weak"]
                             hint:decision.fetchHint completion:nil];
    }
    if (decision.syncAfterTime != nil) {
        // CP-56 "Late identifier resolution" — additive, never gated on the rest of this decision (in
        // particular must still schedule even when the payload above was rejected as stale). Fire-and-
        // forget, outside the lock, like the other triggers.
        [self scheduleSyncAfterTime:source delayMs:[decision.syncAfterTime longLongValue]
                         identifiers:ids userId:userId deviceId:deviceId];
    }
    // decision.continuePaging (multi-object paging) is wired with the popups/inbox sources (.23/.24).
}

#pragma mark - syncAfterTime (CP-56 "Late identifier resolution")

/// Schedule (or coalesce into an already-scheduled) the ONE extra explicit sync requested via
/// `syncAfterTime`. Additive: never suppresses, postpones, or replaces any other sync trigger.
/// Persists the due date so it survives a process restart; the in-memory timer is rearmed from that
/// persisted value in registerSource.
- (void)scheduleSyncAfterTime:(NSString *)source delayMs:(long long)delayMs
                   identifiers:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId {
    @try {
        long long dueDate;
        @synchronized ([self procLockForSource:source]) {
            WPSyncSourceState *state = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
            long long now = self.nowProvider();
            dueDate = [WPSyncFetchPolicy coalesceSyncAfterTimeDueDateAtNow:now delayMs:(double)delayMs
                                                             existingDueDate:state.syncAfterTimeDueDate];
            if (dueDate != state.syncAfterTimeDueDate) {
                state.syncAfterTimeDueDate = dueDate;
                [self.stateStore saveState:state forSource:source userId:userId deviceId:deviceId];
            }
        }
        [self armSyncAfterTimeTimerForSource:source dueDate:dueDate identifiers:ids userId:userId deviceId:deviceId];
    } @catch (NSException *e) {
        WPLog(@"WPSync: syncAfterTime scheduling failed for %@: %@", source, e);
    }
}

/// (Re)arm the in-memory timer for a source's syncAfterTime due date, cancelling any previous timer
/// for that source (repeated hints must not stack up parallel timers, or a superseded-but-still-live
/// timer would fire a redundant extra fetch after an earlier-coalesced one already did).
- (void)armSyncAfterTimeTimerForSource:(NSString *)source dueDate:(long long)dueDate
                             identifiers:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId {
    [self.registryLock lock];
    dispatch_block_t previous = self.syncAfterTimeTimers[source];
    [self.syncAfterTimeTimers removeObjectForKey:source];
    [self.registryLock unlock];
    if (previous != nil) dispatch_block_cancel(previous);

    if (dueDate <= 0) return;   // "nothing scheduled": only clears a pending timer

    double delayMs = (double)(dueDate - self.nowProvider());
    __weak typeof(self) weakSelf = self;
    dispatch_block_t work = dispatch_block_create(0, ^{
        typeof(self) self2 = weakSelf;
        if (!self2) return;
        [self2.registryLock lock];
        [self2.syncAfterTimeTimers removeObjectForKey:source];
        [self2.registryLock unlock];
        [self2 fireSyncAfterTimeForSource:source expectedDueDate:dueDate identifiers:ids userId:userId deviceId:deviceId];
    });
    [self.registryLock lock];
    self.syncAfterTimeTimers[source] = work;
    [self.registryLock unlock];
    self.scheduler(delayMs, work);
}

/// The scheduled extra explicit sync fires: clear the persisted due date (only if it's still the one
/// we armed for — a newer, earlier hint may have coalesced to an earlier time and already fired and
/// cleared it) and trigger a normal (non-weak, no hint) explicit fetch. Still subject to the
/// per-source rate-limit floor via the fetcher's own gating — that's intentional (algorithm.md CP-56
/// requirement).
- (void)fireSyncAfterTimeForSource:(NSString *)source expectedDueDate:(long long)expectedDueDate
                        identifiers:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId {
    @try {
        @synchronized ([self procLockForSource:source]) {
            WPSyncSourceState *state = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
            if (state.syncAfterTimeDueDate == expectedDueDate) {
                state.syncAfterTimeDueDate = 0;
                [self.stateStore saveState:state forSource:source userId:userId deviceId:deviceId];
            }
        }
    } @catch (NSException *e) {
        WPLog(@"WPSync: syncAfterTime firing failed to clear due date for %@: %@", source, e);
    }
    [self.fetcher fetchSource:source userId:userId deviceId:deviceId identifiers:ids
                        knobs:[self effectiveKnobs] weak:NO hint:nil completion:nil];
}

/// Fold the decision's data transforms into the new state and persist once, under the captured
/// profile. The plug-in supplies PURE transforms; the orchestrator owns the data + its persistence,
/// so metadata and data can never split across profiles.
- (void)applyDecision:(WPSyncDecision *)decision source:(NSString *)source
                userId:(NSString *)userId deviceId:(NSString *)deviceId {
    WPSyncSourceState *next = decision.nextState;
    if (next == nil) return;   // no state change (and thus no data to apply)
    id<WPSyncSourcePlugin> plugin = [self pluginForSource:source];
    if (decision.clearState) {
        next.data = nil;
    }
    if (decision.hasApplyData) {
        next.data = [plugin respondsToSelector:@selector(dataByApplyingData:toCurrentData:)]
            ? [plugin dataByApplyingData:decision.applyData toCurrentData:next.data]
            : decision.applyData;   // no plug-in transform: raw replace
    }
    if (decision.hasApplyDelta && [plugin respondsToSelector:@selector(dataByApplyingDelta:toCurrentData:)]) {
        next.data = [plugin dataByApplyingDelta:decision.applyDelta toCurrentData:next.data];
    }
    [self.stateStore saveState:next forSource:source userId:userId deviceId:deviceId];
}

#pragma mark - max-age forcing

- (void)checkMaxAgeForcingWithIdentifiers:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId {
    WPSyncKnobs *knobs = [self effectiveKnobs];
    if (!isfinite(knobs.maxLastSyncDateAgeMs) && !isfinite(knobs.maxLastReadDateAgeMs)) return;   // fast path: no forcing
    long long now = self.nowProvider();
    for (NSString *source in [self registeredSources]) {
        WPSyncSourceState *state = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
        if ([WPSyncKnobs isStateStale:state knobs:knobs now:now]) {
            [self.fetcher fetchSource:source userId:userId deviceId:deviceId identifiers:ids
                                knobs:knobs weak:NO hint:nil completion:nil];   // firm, non-debounced
        }
    }
}

#pragma mark - read

- (id)dataForSource:(NSString *)source {
    NSDictionary *ids = [self currentValidIdentifiers];
    if (ids == nil) return nil;
    return [self.stateStore loadSource:source userId:ids[@"userId"] deviceId:ids[@"deviceId"]].data;
}

@end
