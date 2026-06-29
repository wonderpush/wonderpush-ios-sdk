//
//  WPSyncOutgoing.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncOutgoing.h"
#import "WPSyncSourceState.h"

@implementation WPSyncOutgoing

+ (BOOL)shouldInjectForPath:(NSString *)path {
    static NSArray<NSString *> *suffixes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ suffixes = @[@"/events", @"/installation"]; });

    if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
    for (NSString *suffix in suffixes) {
        // Exact or suffix match only — host-agnostic (covers SDK API + Measurements API), and MUST
        // mirror WPSyncProcessor's classifier (exact/hasSuffix). Injecting on a path the classifier
        // won't classify would leak identifiers + state onto a request whose response is never
        // processed. (Deliberately narrower than the JS reference's defensive "contains <suffix>/"
        // clause, which only matched nested paths the WonderPush API does not expose.)
        if ([path isEqualToString:suffix] || [path hasSuffix:suffix]) return YES;
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

    // 2. Per-source state under _<source>Sync.* keys (algorithm.md:87-91), via the shared encoder.
    for (NSString *source in statePerSource) {
        NSString *prefix = [NSString stringWithFormat:@"_%@Sync.", source];
        [statePerSource[source] writeWireParamsWithPrefix:prefix into:out];
    }

    return out;
}

@end
