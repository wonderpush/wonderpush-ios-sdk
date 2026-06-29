//
//  WPSyncOutgoing.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncOutgoing.h"
#import "WPSyncSourceState.h"
#import "WPSyncProcessor.h"

@implementation WPSyncOutgoing

+ (BOOL)shouldInjectForPath:(NSString *)path method:(NSString *)method {
    // Inject iff the response would be classified opportunistic — i.e. POST /events or
    // PATCH /installation (host-agnostic). Delegating to the classifier guarantees the inject set and
    // the processed set are identical, and that a GET/PUT/DELETE on those suffixes is NOT injected.
    return [[WPSyncProcessor classifyResponsePath:path method:method].mode isEqualToString:@"opportunistic"];
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

    // 2. Per-source state under _<source>Sync.* keys (algorithm.md:87-91), via the shared encoder.
    for (NSString *source in statePerSource) {
        NSString *prefix = [NSString stringWithFormat:@"_%@Sync.", source];
        [statePerSource[source] writeWireParamsWithPrefix:prefix into:out];
    }

    return out;
}

@end
