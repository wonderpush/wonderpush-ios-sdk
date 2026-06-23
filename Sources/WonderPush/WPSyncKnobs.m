//
//  WPSyncKnobs.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncKnobs.h"

static double WPSyncDouble(NSDictionary *dict, NSString *key) {
    id value = dict[key];
    return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0;
}

@implementation WPSyncKnobs

+ (instancetype)knobsWithDictionary:(NSDictionary *)dict {
    WPSyncKnobs *knobs = [WPSyncKnobs new];
    if (![dict isKindOfClass:[NSDictionary class]]) return knobs;
    knobs.weakSyncSignalDebounceMs = WPSyncDouble(dict, @"weakSyncSignalDebounceMs");
    knobs.maxLastSyncDateAgeMs = WPSyncDouble(dict, @"maxLastSyncDateAgeMs");
    knobs.maxLastReadDateAgeMs = WPSyncDouble(dict, @"maxLastReadDateAgeMs");
    knobs.maxPopupsEntries = (NSInteger)WPSyncDouble(dict, @"maxPopupsEntries");
    knobs.maxInboxEntries = (NSInteger)WPSyncDouble(dict, @"maxInboxEntries");
    knobs.exponentialBackoffMinMs = WPSyncDouble(dict, @"exponentialBackoffMinMs");
    knobs.exponentialBackoffMaxMs = WPSyncDouble(dict, @"exponentialBackoffMaxMs");
    knobs.exponentialBackoffRatio = WPSyncDouble(dict, @"exponentialBackoffRatio");
    knobs.exponentialBackoffJitterRatio = WPSyncDouble(dict, @"exponentialBackoffJitterRatio");
    knobs.mutexTtlMs = WPSyncDouble(dict, @"mutexTtlMs");
    knobs.opportunisticInjectionEnabled = [dict[@"opportunisticInjectionEnabled"] boolValue];
    knobs.minSourceFetchIntervalMs = WPSyncDouble(dict, @"minSourceFetchIntervalMs");
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

@end
