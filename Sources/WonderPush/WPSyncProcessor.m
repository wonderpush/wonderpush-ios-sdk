//
//  WPSyncProcessor.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncProcessor.h"
#import "WPSyncVersionId.h"

@implementation WPSyncResponseClassification
- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary new];
    d[@"mode"] = self.mode ?: @"none";
    if (self.explicitSource != nil) d[@"explicitSource"] = self.explicitSource;
    return d;
}
@end

/// Accepts both '/events' and '/v1/events'-prefixed forms. The leading '/' in each suffix enforces a
/// path-segment boundary, so '/foo-inbox' does not match '/inbox'.
static BOOL nWPSyncPathMatchesSuffix(NSString *path, NSString *suffix) {
    return [path isEqualToString:suffix] || [path hasSuffix:suffix];
}

/// NSNull -> nil; otherwise pass through. Normalizes a VersionId from a response block.
static id _Nullable nWPSyncDenull(id _Nullable v) {
    return v == [NSNull null] ? nil : v;
}

@implementation WPSyncProcessor

#pragma mark - classifyResponse

+ (WPSyncResponseClassification *)classifyResponsePath:(NSString *)path method:(NSString *)method {
    WPSyncResponseClassification *c = [WPSyncResponseClassification new];
    c.mode = @"none";
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return c;
    NSString *m = [(method ?: @"") uppercaseString];

    NSArray<NSString *> *oppPaths = @{ @"POST": @[@"/events"], @"PATCH": @[@"/installation"] }[m];
    for (NSString *suffix in oppPaths) {
        if (nWPSyncPathMatchesSuffix(path, suffix)) { c.mode = @"opportunistic"; return c; }
    }

    if ([m isEqualToString:@"GET"]) {
        NSDictionary<NSString *, NSString *> *explicit = @{
            @"/contact": @"contact", @"/user": @"user", @"/installation": @"installation",
            @"/popups": @"popups", @"/inbox": @"inbox",
        };
        for (NSString *suffix in explicit) {  // suffixes are mutually exclusive; iteration order is irrelevant
            if (nWPSyncPathMatchesSuffix(path, suffix)) {
                c.mode = @"explicit";
                c.explicitSource = explicit[suffix];
                return c;
            }
        }
    }
    return c;
}

#pragma mark - processSourceBlock

+ (WPSyncFetchHint *)buildFetchHint:(WPSyncResponseBlock *)block {
    WPSyncFetchHint *h = [WPSyncFetchHint new];
    if (block.knownVersion != nil) h.knownVersion = block.knownVersion;
    if (block.hasKnownVersionId) h.knownVersionId = block.knownVersionId;
    if (block.knownReadDate != nil) h.knownReadDate = block.knownReadDate;
    return h;
}

+ (WPSyncDecision *)processSourceBlock:(WPSyncResponseBlock *)block
                            serverTime:(NSNumber *)serverTime
                                 state:(WPSyncSourceState *)state
                                  mode:(NSString *)mode {
    WPSyncDecision *decision = [WPSyncDecision new];

    // 1. Block missing -> do nothing.
    if (block == nil) return decision;

    // 2. Empty {} -> "try asking explicitly" (opportunistic) or nothing (explicit).
    if (block.isEmpty) {
        if ([mode isEqualToString:@"opportunistic"]) decision.triggerFetch = @"weak";
        return decision;
    }

    WPSyncSourceState *next = [state copy];
    BOOL stateChanged = NO;

    // 3. meta is opaque — store + echo only, no acceptance gate.
    if (block.meta != nil) { next.lastSyncMeta = block.meta; stateChanged = YES; }

    BOOL hasPayload = block.hasData || block.hasDelta;
    if (hasPayload) {
        // 4. Payload-bearing: acceptance check.
        long long version = block.version ? [block.version longLongValue] : 0;
        long long readDate = block.readDate ? [block.readDate longLongValue] : 0;
        id data = block.hasData ? block.data : nil;
        BOOL accepted = [WPSyncVersionId acceptsResponseWithVersion:version
                                                          versionId:(block.hasVersionId ? block.versionId : nil)
                                                           readDate:readDate
                                                               data:data
                                                        lastVersion:state.lastVersion
                                                      lastVersionId:state.lastVersionId
                                                       lastReadDate:state.lastReadDate];
        if (!accepted) {
            // Stale/out-of-order: drop payload, but keep any meta update already captured.
            if (stateChanged) decision.nextState = next;
            return decision;
        }

        if (version == 0 && [WPSyncVersionId isEmptyDataPayload:data]) decision.clearState = YES;
        if (block.hasData) { decision.hasApplyData = YES; decision.applyData = block.data; }
        if (block.hasDelta) { decision.hasApplyDelta = YES; decision.applyDelta = block.delta; }

        if (block.version != nil) next.lastVersion = version;
        if (block.hasVersionId) next.lastVersionId = nWPSyncDenull(block.versionId);
        if (block.readDate != nil && readDate > state.lastReadDate) next.lastReadDate = readDate;
        stateChanged = YES;
    } else {
        // 5. No payload: "no change confirmed" or hint-only.
        if (block.version != nil && block.hasVersionId) {
            long long bver = [block.version longLongValue];
            NSComparisonResult idCmp = [WPSyncVersionId compareVersionId:nWPSyncDenull(block.versionId)
                                                                    with:state.lastVersionId];
            if (bver == state.lastVersion && idCmp == NSOrderedSame) {
                if (block.readDate != nil && [block.readDate longLongValue] > next.lastReadDate) {
                    next.lastReadDate = [block.readDate longLongValue];
                    stateChanged = YES;
                }
            } else if (bver > state.lastVersion || (bver == state.lastVersion && idCmp == NSOrderedDescending)) {
                decision.triggerFetch = @"firm";
            }
            // strictly lower: ignore
        } else if (block.readDate != nil) {
            // Degenerate "no change confirmed" — only readDate.
            long long brd = [block.readDate longLongValue];
            if (brd >= state.lastReadDate && brd > next.lastReadDate) {
                next.lastReadDate = brd;
                stateChanged = YES;
            }
        }
    }

    // 6. Advance lastSyncDate from _serverTime if higher.
    if (serverTime != nil && [serverTime longLongValue] > next.lastSyncDate) {
        next.lastSyncDate = [serverTime longLongValue];
        stateChanged = YES;
    }

    // 7. Head hints — compared against the (possibly just-updated) lastVersion.
    if (block.knownVersion != nil && block.hasKnownVersionId) {
        long long kver = [block.knownVersion longLongValue];
        NSComparisonResult headIdCmp = [WPSyncVersionId compareVersionId:nWPSyncDenull(block.knownVersionId)
                                                                    with:next.lastVersionId];
        if (kver > next.lastVersion || (kver == next.lastVersion && headIdCmp == NSOrderedDescending)) {
            decision.fetchHint = [self buildFetchHint:block];
            if ([mode isEqualToString:@"explicit"]) {
                decision.continuePaging = YES;   // more pages remain; orchestrator continues, floor-exempt
            } else {
                decision.triggerFetch = @"firm";
            }
        }
    } else if (block.knownReadDate != nil && block.knownVersion == nil) {
        // Weak hint (knownReadDate only). Debounced fetch; don't downgrade an existing firm decision.
        if ([block.knownReadDate longLongValue] > next.lastReadDate && decision.triggerFetch == nil) {
            decision.triggerFetch = @"weak";
            decision.fetchHint = [self buildFetchHint:block];
        }
    }

    if (stateChanged) decision.nextState = next;
    return decision;
}

@end
