//
//  WPSyncKnobs.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncKnobs.h"
#import "WPSyncSourceState.h"
#import <math.h>

static double nWPSyncDouble(NSDictionary *dict, NSString *key) {
    id value = dict[key];
    return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0;
}

/// Mirrors the JS pickNumber: accept only a real (non-NaN) JS number. A boolean NSNumber is NOT a
/// number (JS `typeof true === 'boolean'`), and a numeric 0 is NOT boolean false — both distinctions
/// matter for the kill switch and overrides, so we test CFBoolean identity explicitly.
static BOOL nWPSyncIsBoolean(id value) {
    return value != nil && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static double nWPSyncPickNumber(NSDictionary *data, NSString *key, double fallback) {
    id c = data[key];
    if ([c isKindOfClass:[NSNumber class]] && !nWPSyncIsBoolean(c)) {
        double d = [c doubleValue];
        if (!isnan(d)) return d;
    }
    return fallback;
}

@implementation WPSyncKnobs

+ (instancetype)knobsWithDictionary:(NSDictionary *)dict {
    WPSyncKnobs *knobs = [WPSyncKnobs new];
    if (![dict isKindOfClass:[NSDictionary class]]) return knobs;
    knobs.weakSyncSignalDebounceMs = nWPSyncDouble(dict, @"weakSyncSignalDebounceMs");
    knobs.maxLastSyncDateAgeMs = nWPSyncDouble(dict, @"maxLastSyncDateAgeMs");
    knobs.maxLastReadDateAgeMs = nWPSyncDouble(dict, @"maxLastReadDateAgeMs");
    knobs.maxPopupsEntries = (NSInteger)nWPSyncDouble(dict, @"maxPopupsEntries");
    knobs.maxInboxEntries = (NSInteger)nWPSyncDouble(dict, @"maxInboxEntries");
    knobs.exponentialBackoffMinMs = nWPSyncDouble(dict, @"exponentialBackoffMinMs");
    knobs.exponentialBackoffMaxMs = nWPSyncDouble(dict, @"exponentialBackoffMaxMs");
    knobs.exponentialBackoffRatio = nWPSyncDouble(dict, @"exponentialBackoffRatio");
    knobs.exponentialBackoffJitterRatio = nWPSyncDouble(dict, @"exponentialBackoffJitterRatio");
    knobs.mutexTtlMs = nWPSyncDouble(dict, @"mutexTtlMs");
    knobs.opportunisticInjectionEnabled = [dict[@"opportunisticInjectionEnabled"] boolValue];
    knobs.minSourceFetchIntervalMs = nWPSyncDouble(dict, @"minSourceFetchIntervalMs");
    return knobs;
}

- (NSDictionary *)toDictionary {
    return @{
        @"weakSyncSignalDebounceMs": @(self.weakSyncSignalDebounceMs),
        @"maxLastSyncDateAgeMs": @(self.maxLastSyncDateAgeMs),
        @"maxLastReadDateAgeMs": @(self.maxLastReadDateAgeMs),
        @"maxPopupsEntries": @(self.maxPopupsEntries),
        @"maxInboxEntries": @(self.maxInboxEntries),
        @"exponentialBackoffMinMs": @(self.exponentialBackoffMinMs),
        @"exponentialBackoffMaxMs": @(self.exponentialBackoffMaxMs),
        @"exponentialBackoffRatio": @(self.exponentialBackoffRatio),
        @"exponentialBackoffJitterRatio": @(self.exponentialBackoffJitterRatio),
        @"mutexTtlMs": @(self.mutexTtlMs),
        @"opportunisticInjectionEnabled": @(self.opportunisticInjectionEnabled),
        @"minSourceFetchIntervalMs": @(self.minSourceFetchIntervalMs),
    };
}

- (id)copyWithZone:(NSZone *)zone {
    return [WPSyncKnobs knobsWithDictionary:[self toDictionary]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[WPSyncKnobs class]]) return NO;
    WPSyncKnobs *o = object;
    return self.weakSyncSignalDebounceMs == o.weakSyncSignalDebounceMs
        && self.maxLastSyncDateAgeMs == o.maxLastSyncDateAgeMs
        && self.maxLastReadDateAgeMs == o.maxLastReadDateAgeMs
        && self.maxPopupsEntries == o.maxPopupsEntries
        && self.maxInboxEntries == o.maxInboxEntries
        && self.exponentialBackoffMinMs == o.exponentialBackoffMinMs
        && self.exponentialBackoffMaxMs == o.exponentialBackoffMaxMs
        && self.exponentialBackoffRatio == o.exponentialBackoffRatio
        && self.exponentialBackoffJitterRatio == o.exponentialBackoffJitterRatio
        && self.mutexTtlMs == o.mutexTtlMs
        && self.opportunisticInjectionEnabled == o.opportunisticInjectionEnabled
        && self.minSourceFetchIntervalMs == o.minSourceFetchIntervalMs;
}

- (NSUInteger)hash {
    return [@(self.weakSyncSignalDebounceMs) hash] ^ [@(self.minSourceFetchIntervalMs) hash];
}

+ (instancetype)defaultKnobs {
    WPSyncKnobs *k = [WPSyncKnobs new];
    k.weakSyncSignalDebounceMs = 5000;
    k.maxLastSyncDateAgeMs = INFINITY;
    k.maxLastReadDateAgeMs = INFINITY;
    k.maxPopupsEntries = 1000;
    k.maxInboxEntries = 1000;
    k.exponentialBackoffMinMs = 1000;
    k.exponentialBackoffMaxMs = 300000;
    k.exponentialBackoffRatio = 2;
    k.exponentialBackoffJitterRatio = 0.5;
    k.mutexTtlMs = 600000;
    k.opportunisticInjectionEnabled = YES;
    k.minSourceFetchIntervalMs = 2000;
    return k;
}

+ (instancetype)mergeKnobsFromDefaults:(WPSyncKnobs *)d remoteConfig:(NSDictionary *)data {
    WPSyncKnobs *k = [d copy];
    if (![data isKindOfClass:[NSDictionary class]]) return k;  // null / non-dict -> defaults
    k.weakSyncSignalDebounceMs = nWPSyncPickNumber(data, @"syncWeakSignalDebounceMs", d.weakSyncSignalDebounceMs);
    k.maxLastSyncDateAgeMs = nWPSyncPickNumber(data, @"syncMaxLastSyncDateAgeMs", d.maxLastSyncDateAgeMs);
    k.maxLastReadDateAgeMs = nWPSyncPickNumber(data, @"syncMaxLastReadDateAgeMs", d.maxLastReadDateAgeMs);
    k.maxPopupsEntries = (NSInteger)nWPSyncPickNumber(data, @"syncMaxPopupsEntries", (double)d.maxPopupsEntries);
    k.maxInboxEntries = (NSInteger)nWPSyncPickNumber(data, @"syncMaxInboxEntries", (double)d.maxInboxEntries);
    k.exponentialBackoffMinMs = nWPSyncPickNumber(data, @"syncBackoffMinMs", d.exponentialBackoffMinMs);
    k.exponentialBackoffMaxMs = nWPSyncPickNumber(data, @"syncBackoffMaxMs", d.exponentialBackoffMaxMs);
    k.exponentialBackoffRatio = nWPSyncPickNumber(data, @"syncBackoffRatio", d.exponentialBackoffRatio);
    k.exponentialBackoffJitterRatio = nWPSyncPickNumber(data, @"syncBackoffJitterRatio", d.exponentialBackoffJitterRatio);
    k.mutexTtlMs = nWPSyncPickNumber(data, @"syncMutexTtlMs", d.mutexTtlMs);
    k.minSourceFetchIntervalMs = nWPSyncPickNumber(data, @"syncMinSourceFetchIntervalMs", d.minSourceFetchIntervalMs);
    // Kill switch: disable only on explicit boolean false (matches JS `value !== false`); a numeric
    // 0 or a missing key keeps injection enabled.
    id inj = data[@"syncOpportunisticInjection"];
    k.opportunisticInjectionEnabled = !(nWPSyncIsBoolean(inj) && ![inj boolValue]);
    return k;
}

+ (BOOL)isStateStale:(WPSyncSourceState *)state knobs:(WPSyncKnobs *)knobs now:(long long)now {
    if (state.lastSyncDate > 0 && isfinite(knobs.maxLastSyncDateAgeMs)) {
        if ((double)(now - state.lastSyncDate) > knobs.maxLastSyncDateAgeMs) return YES;
    }
    if (state.lastReadDate > 0 && isfinite(knobs.maxLastReadDateAgeMs)) {
        if ((double)(now - state.lastReadDate) > knobs.maxLastReadDateAgeMs) return YES;
    }
    return NO;
}

@end
