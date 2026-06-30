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
#import <math.h>

@interface WPSync ()
@property (nonatomic, strong) WPSyncStateStore *stateStore;
@property (nonatomic, strong) id<WPSyncFetching> fetcher;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *sources;          // name -> plugin or NSNull
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSObject *> *procLocks; // name -> per-source lock
@property (nonatomic, strong) NSLock *registryLock;
@end

@implementation WPSync

- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore fetcher:(id<WPSyncFetching>)fetcher {
    if (self = [super init]) {
        _stateStore = stateStore;
        _fetcher = fetcher;
        _sources = [NSMutableDictionary new];
        _procLocks = [NSMutableDictionary new];
        _registryLock = [NSLock new];
        _identifiersProvider = ^NSDictionary *{ return @{}; };
        _knobsProvider = ^WPSyncKnobs *{ return [WPSyncKnobs defaultKnobs]; };
        _nowProvider = ^long long{ return (long long)([[NSDate date] timeIntervalSince1970] * 1000.0); };
    }
    return self;
}

#pragma mark - registry

- (void)registerSource:(NSString *)name plugin:(id<WPSyncSourcePlugin>)plugin {
    [self.registryLock lock];
    self.sources[name] = plugin ?: (id)[NSNull null];
    if (!self.procLocks[name]) self.procLocks[name] = [NSObject new];
    [self.registryLock unlock];
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

#pragma mark - outgoing

- (NSDictionary *)prepareOutgoingParamsForPath:(NSString *)path method:(NSString *)method {
    if (![WPSyncOutgoing shouldInjectForPath:path method:method]) return @{};
    WPSyncKnobs *knobs = self.knobsProvider();
    if (!knobs.opportunisticInjectionEnabled) return @{};
    NSDictionary *ids = self.identifiersProvider() ?: @{};
    NSString *userId = ids[@"userId"];
    NSString *deviceId = ids[@"deviceId"];
    if (![deviceId isKindOfClass:[NSString class]] || deviceId.length == 0) return @{};   // deviceId invariant

    NSMutableDictionary<NSString *, WPSyncSourceState *> *statePerSource = [NSMutableDictionary new];
    for (NSString *source in [self registeredSources]) {
        statePerSource[source] = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
    }
    return [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:ids statePerSource:statePerSource];
}

#pragma mark - incoming

- (void)consumeIncomingResponseForPath:(NSString *)path method:(NSString *)method response:(NSDictionary *)response {
    if (![response isKindOfClass:[NSDictionary class]]) return;
    WPSyncResponseClassification *c = [WPSyncProcessor classifyResponsePath:path method:method];
    if ([c.mode isEqualToString:@"none"]) return;

    NSDictionary *ids = self.identifiersProvider() ?: @{};
    NSString *userId = ids[@"userId"];
    NSString *deviceId = ids[@"deviceId"];
    if (![deviceId isKindOfClass:[NSString class]] || deviceId.length == 0) return;   // deviceId invariant

    NSNumber *serverTime = [response[@"_serverTime"] isKindOfClass:[NSNumber class]] ? response[@"_serverTime"] : nil;

    if ([c.mode isEqualToString:@"opportunistic"]) {
        // Iterate ALL registered sources (the processor handles a missing block correctly).
        for (NSString *source in [self registeredSources]) {
            id block = response[[NSString stringWithFormat:@"_%@Sync", source]];
            [self processSource:source blockDict:block serverTime:serverTime ids:ids
                         userId:userId deviceId:deviceId mode:@"opportunistic"];
        }
    } else if (c.explicitSource) {
        [self processSource:c.explicitSource blockDict:[self extractExplicitBlock:response] serverTime:serverTime
                        ids:ids userId:userId deviceId:deviceId mode:@"explicit"];
    }

    [self checkMaxAgeForcingWithIdentifiers:ids userId:userId deviceId:deviceId];
}

/// Project the recognized block fields out of an explicit response root.
- (NSDictionary *)extractExplicitBlock:(NSDictionary *)response {
    static NSArray *fields;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fields = @[@"meta", @"version", @"versionId", @"readDate", @"data", @"delta",
                   @"knownVersion", @"knownVersionId", @"knownReadDate"];
    });
    NSMutableDictionary *block = [NSMutableDictionary new];
    for (NSString *k in fields) {
        id v = response[k];
        if (v != nil) block[k] = v;
    }
    return block;
}

/// Serialized per source: load -> process -> execute decision. The per-source lock spans the whole
/// read-modify-write so concurrent responses for the same source can't clobber state.
- (void)processSource:(NSString *)source blockDict:(id)blockDict serverTime:(NSNumber *)serverTime
                  ids:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId mode:(NSString *)mode {
    @synchronized ([self procLockForSource:source]) {
        WPSyncSourceState *state = [self.stateStore loadSource:source userId:userId deviceId:deviceId];
        WPSyncResponseBlock *block = [blockDict isKindOfClass:[NSDictionary class]]
            ? [WPSyncResponseBlock blockWithDictionary:blockDict] : nil;
        WPSyncDecision *decision = [WPSyncProcessor processSourceBlock:block serverTime:serverTime state:state mode:mode];
        [self executeDecision:decision source:source ids:ids userId:userId deviceId:deviceId];
    }
}

/// Apply a decision: save state, run plug-in callbacks (clearState -> applyData -> applyDelta), fetch.
- (void)executeDecision:(WPSyncDecision *)decision source:(NSString *)source
                    ids:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId {
    if (decision.nextState != nil) {
        [self.stateStore saveState:decision.nextState forSource:source userId:userId deviceId:deviceId];
    }
    id<WPSyncSourcePlugin> plugin = [self pluginForSource:source];
    if (decision.clearState && [plugin respondsToSelector:@selector(clearState)]) {
        [plugin clearState];
    }
    if (decision.hasApplyData && [plugin respondsToSelector:@selector(applyData:)]) {
        [plugin applyData:decision.applyData];
    }
    if (decision.hasApplyDelta && [plugin respondsToSelector:@selector(applyDelta:)]) {
        [plugin applyDelta:decision.applyDelta];
    }
    if (decision.triggerFetch != nil) {
        // Fire-and-forget; forward the head hint so the explicit request can echo known* fields.
        [self.fetcher fetchSource:source userId:userId deviceId:deviceId identifiers:ids
                            knobs:self.knobsProvider()
                             weak:[decision.triggerFetch isEqualToString:@"weak"]
                             hint:decision.fetchHint completion:nil];
    }
    // decision.continuePaging (multi-object paging) is wired with the popups/inbox sources (.23/.24).
}

#pragma mark - max-age forcing

- (void)checkMaxAgeForcingWithIdentifiers:(NSDictionary *)ids userId:(NSString *)userId deviceId:(NSString *)deviceId {
    WPSyncKnobs *knobs = self.knobsProvider();
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
    NSDictionary *ids = self.identifiersProvider() ?: @{};
    NSString *deviceId = ids[@"deviceId"];
    if (![deviceId isKindOfClass:[NSString class]] || deviceId.length == 0) return nil;
    return [self.stateStore loadSource:source userId:ids[@"userId"] deviceId:deviceId].data;
}

@end
