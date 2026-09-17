//
//  WPSyncFetchPolicy.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncFetchPolicy.h"
#import "WPSyncKnobs.h"
#import "WPSyncSourceState.h"
#import "WPSyncDecision.h"   // WPSyncFetchHint
#import <math.h>

NSString * _Nullable WPSyncExplicitPathForSource(NSString *source) {
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Explicit sync endpoints live under the dedicated `/sync/` namespace (GET /v1/sync/{source}),
        // keeping them distinct from the opportunistic resource paths (POST /v1/events, PATCH
        // /v1/installation). No `/v1` prefix — Rest prepends the version segment.
        map = @{ @"contact": @"/sync/contact", @"user": @"/sync/user", @"installation": @"/sync/installation",
                 @"popups": @"/sync/popups", @"inbox": @"/sync/inbox" };
    });
    return map[source ?: @""];
}

/// True iff value is a non-empty string (mirrors JS truthiness for the identifier fields).
static BOOL nWPSyncNonEmptyString(id value) {
    return [value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0;
}

@implementation WPSyncFetchPolicy

+ (BOOL)shouldDebounceWeakSignalAtNow:(long long)now
                lastFetchAttemptedDate:(long long)lastFetchAttemptedDate
                            debounceMs:(double)debounceMs {
    return lastFetchAttemptedDate > 0 && (double)(now - lastFetchAttemptedDate) < debounceMs;
}

+ (BOOL)shouldRateLimitSourceAtNow:(long long)now
            lastFetchAttemptedDate:(long long)lastFetchAttemptedDate
                     minIntervalMs:(double)minIntervalMs {
    return minIntervalMs > 0 && lastFetchAttemptedDate > 0 && (double)(now - lastFetchAttemptedDate) < minIntervalMs;
}

+ (double)computeBackoffSleepWithAttemptCount:(NSInteger)attemptCount
                                         rand:(double)rand
                                        knobs:(WPSyncKnobs *)knobs {
    if (attemptCount <= 0) return 0;
    double raw = knobs.exponentialBackoffMinMs * pow(knobs.exponentialBackoffRatio, (double)attemptCount);
    double capped = MIN(knobs.exponentialBackoffMaxMs, raw);
    return capped * (1 + rand * knobs.exponentialBackoffJitterRatio);
}

+ (NSDictionary *)buildExplicitFetchParamsWithIdentifiers:(NSDictionary *)identifiers
                                                    state:(WPSyncSourceState *)state
                                                     hint:(WPSyncFetchHint *)hint {
    NSMutableDictionary *params = [NSMutableDictionary new];

    // Identifiers (NEVER contactId; userId is added by the request layer from the session).
    for (NSString *key in @[@"deviceId", @"installationId", @"visitorId"]) {
        id value = identifiers[key];
        if (nWPSyncNonEmptyString(value)) params[key] = value;
    }

    // Sync state at the top level (explicit-fetch shape, no `_<source>Sync.` prefix), via the
    // shared encoder also used by the opportunistic injection path (WPSyncOutgoing).
    [state writeWireParamsWithPrefix:@"" into:params];

    // Echoed head hints, when the fetch was triggered by one. Skip absent / null fields.
    if (hint != nil) {
        if (hint.knownVersion != nil) params[@"knownVersion"] = hint.knownVersion;
        if (hint.knownVersionId != nil && hint.knownVersionId != [NSNull null]) {
            params[@"knownVersionId"] = hint.knownVersionId;
        }
        if (hint.knownReadDate != nil) params[@"knownReadDate"] = hint.knownReadDate;
    }

    return params;
}

@end
