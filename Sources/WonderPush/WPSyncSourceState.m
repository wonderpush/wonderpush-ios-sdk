//
//  WPSyncSourceState.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncSourceState.h"

/// Two values are considered equal if they are both nil or `isEqual:`.
static BOOL WPSyncNilSafeEqual(id _Nullable a, id _Nullable b) {
    if (a == nil && b == nil) return YES;
    if (a == nil || b == nil) return NO;
    return [a isEqual:b];
}

/// Reads a value from a JSON-decoded dictionary, mapping NSNull and missing keys to nil.
static id _Nullable WPSyncValueOrNil(NSDictionary *dict, NSString *key) {
    id value = dict[key];
    if (value == nil || value == [NSNull null]) return nil;
    return value;
}

static long long WPSyncLongLong(NSDictionary *dict, NSString *key) {
    id value = WPSyncValueOrNil(dict, key);
    return [value isKindOfClass:[NSNumber class]] ? [value longLongValue] : 0;
}

@implementation WPSyncSourceState

+ (instancetype)emptyState {
    return [WPSyncSourceState new];
}

+ (instancetype)stateWithDictionary:(NSDictionary *)dict {
    WPSyncSourceState *state = [WPSyncSourceState new];
    if (![dict isKindOfClass:[NSDictionary class]]) return state;
    state.lastSyncDate = WPSyncLongLong(dict, @"lastSyncDate");
    id meta = WPSyncValueOrNil(dict, @"lastSyncMeta");
    state.lastSyncMeta = [meta isKindOfClass:[NSDictionary class]] ? meta : nil;
    state.lastVersion = WPSyncLongLong(dict, @"lastVersion");
    state.lastVersionId = WPSyncValueOrNil(dict, @"lastVersionId");
    state.lastReadDate = WPSyncLongLong(dict, @"lastReadDate");
    state.lastFetchAttemptedDate = WPSyncLongLong(dict, @"lastFetchAttemptedDate");
    state.lastFetchUnsuccessfulAttemptCount = (NSInteger)WPSyncLongLong(dict, @"lastFetchUnsuccessfulAttemptCount");
    state.data = WPSyncValueOrNil(dict, @"data");
    return state;
}

- (NSDictionary *)toDictionary {
    return @{
        @"lastSyncDate": @(self.lastSyncDate),
        @"lastSyncMeta": self.lastSyncMeta ?: [NSNull null],
        @"lastVersion": @(self.lastVersion),
        @"lastVersionId": self.lastVersionId ?: [NSNull null],
        @"lastReadDate": @(self.lastReadDate),
        @"lastFetchAttemptedDate": @(self.lastFetchAttemptedDate),
        @"lastFetchUnsuccessfulAttemptCount": @(self.lastFetchUnsuccessfulAttemptCount),
        @"data": self.data ?: [NSNull null],
    };
}

- (id)copyWithZone:(NSZone *)zone {
    WPSyncSourceState *copy = [WPSyncSourceState new];
    copy.lastSyncDate = self.lastSyncDate;
    copy.lastSyncMeta = self.lastSyncMeta;
    copy.lastVersion = self.lastVersion;
    copy.lastVersionId = self.lastVersionId;
    copy.lastReadDate = self.lastReadDate;
    copy.lastFetchAttemptedDate = self.lastFetchAttemptedDate;
    copy.lastFetchUnsuccessfulAttemptCount = self.lastFetchUnsuccessfulAttemptCount;
    copy.data = self.data;
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[WPSyncSourceState class]]) return NO;
    WPSyncSourceState *other = object;
    return self.lastSyncDate == other.lastSyncDate
        && self.lastVersion == other.lastVersion
        && self.lastReadDate == other.lastReadDate
        && self.lastFetchAttemptedDate == other.lastFetchAttemptedDate
        && self.lastFetchUnsuccessfulAttemptCount == other.lastFetchUnsuccessfulAttemptCount
        && WPSyncNilSafeEqual(self.lastSyncMeta, other.lastSyncMeta)
        && WPSyncNilSafeEqual(self.lastVersionId, other.lastVersionId)
        && WPSyncNilSafeEqual(self.data, other.data);
}

- (NSUInteger)hash {
    return (NSUInteger)(self.lastSyncDate ^ self.lastVersion ^ self.lastReadDate
        ^ self.lastFetchAttemptedDate ^ self.lastFetchUnsuccessfulAttemptCount);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p: %@>", NSStringFromClass(self.class), self, [self toDictionary]];
}

@end
