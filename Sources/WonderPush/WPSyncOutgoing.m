//
//  WPSyncOutgoing.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncOutgoing.h"
#import "WPSyncSourceState.h"
#import <WonderPushCommon/WPLog.h>

@implementation WPSyncOutgoing

+ (BOOL)shouldInjectForPath:(NSString *)path {
    static NSArray<NSString *> *suffixes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ suffixes = @[@"/events", @"/installation"]; });

    if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
    for (NSString *suffix in suffixes) {
        // Exact, suffix, or contains "<suffix>/" — host-agnostic (covers SDK API + Measurements API).
        if ([path isEqualToString:suffix]
            || [path hasSuffix:suffix]
            || [path rangeOfString:[suffix stringByAppendingString:@"/"]].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

+ (NSDictionary *)buildOutgoingParamsWithIdentifiers:(NSDictionary *)identifiers
                                      statePerSource:(NSDictionary<NSString *, WPSyncSourceState *> *)statePerSource {
    NSMutableDictionary *out = [NSMutableDictionary new];

    // 1. The 4 identifiers under _sync-prefixed keys; skip empty/missing. NEVER contactId, by design.
    NSDictionary<NSString *, NSString *> *idKeyToParam = @{
        @"userId": @"_syncUserId", @"deviceId": @"_syncDeviceId",
        @"installationId": @"_syncInstallationId", @"visitorId": @"_syncVisitorId",
    };
    for (NSString *idKey in idKeyToParam) {
        id value = identifiers[idKey];
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
            out[idKeyToParam[idKey]] = value;
        }
    }

    // 2. Per-source state under _<source>Sync.* keys (algorithm.md:87-91). Always send the int64 trio;
    // omit lastSyncMeta (JSON-encoded) and lastVersionId when nil — the server defaults them.
    for (NSString *source in statePerSource) {
        WPSyncSourceState *state = statePerSource[source];
        NSString *prefix = [NSString stringWithFormat:@"_%@Sync.", source];
        out[[prefix stringByAppendingString:@"lastSyncDate"]] = @(state.lastSyncDate);
        out[[prefix stringByAppendingString:@"lastVersion"]] = @(state.lastVersion);
        out[[prefix stringByAppendingString:@"lastReadDate"]] = @(state.lastReadDate);
        if (state.lastSyncMeta != nil) {
            NSError *error = nil;
            NSData *json = [NSJSONSerialization dataWithJSONObject:state.lastSyncMeta options:0 error:&error];
            if (json) {
                out[[prefix stringByAppendingString:@"lastSyncMeta"]] = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            } else {
                WPLog(@"WPSyncOutgoing: failed to serialize lastSyncMeta for %@; omitting: %@", source, error);
            }
        }
        if (state.lastVersionId != nil) {
            out[[prefix stringByAppendingString:@"lastVersionId"]] = state.lastVersionId;
        }
    }

    return out;
}

@end
