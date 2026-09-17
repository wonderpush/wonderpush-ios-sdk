//
//  WPSyncPopupsStore.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncPopupsStore.h"

/// The item's "version" for dedupe/precedence is its updateDate (sources.md sorts by updateDate, id).
/// Missing / non-numeric updateDate is treated as 0, mirroring JS `typeof x === 'number' ? x : 0`.
static long long nWPSyncPopupVersion(NSDictionary *item) {
    id v = item[@"updateDate"];
    return [v isKindOfClass:[NSNumber class]] ? [v longLongValue] : 0;
}

/// Expired iff expirationDate is a number strictly less than now. No expirationDate -> never expires.
static BOOL nWPSyncPopupIsExpired(NSDictionary *item, long long now) {
    id exp = item[@"expirationDate"];
    return [exp isKindOfClass:[NSNumber class]] && [exp longLongValue] < now;
}

/// Upsert items by id favoring the highest updateDate (latest wins — including a "deleted" tombstone
/// superseding an older active item), then drop expired items. Later items in `items` win ties, since
/// incoming data is newer than what is already stored. First-seen order is preserved.
static NSArray<NSDictionary *> *nWPSyncDedupeAndPrune(NSArray *items, long long now) {
    NSMutableDictionary<NSString *, NSDictionary *> *byId = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id it in items) {
        if (![it isKindOfClass:[NSDictionary class]]) continue;   // skip malformed entries
        id itemId = ((NSDictionary *)it)[@"id"];
        if (![itemId isKindOfClass:[NSString class]]) continue;
        NSDictionary *existing = byId[itemId];
        if (existing == nil) [order addObject:itemId];
        if (existing == nil || nWPSyncPopupVersion(it) >= nWPSyncPopupVersion(existing)) byId[itemId] = it;
    }
    NSMutableArray<NSDictionary *> *out = [NSMutableArray arrayWithCapacity:order.count];
    for (NSString *itemId in order) {
        NSDictionary *it = byId[itemId];
        if (!nWPSyncPopupIsExpired(it, now)) [out addObject:it];
    }
    return out;
}

@implementation WPSyncPopupsStore

+ (NSArray<NSDictionary *> *)resetPopupsData:(id)data now:(long long)now {
    return nWPSyncDedupeAndPrune([data isKindOfClass:[NSArray class]] ? data : @[], now);
}

+ (NSArray<NSDictionary *> *)applyPopupsDelta:(id)current delta:(id)delta now:(long long)now {
    NSArray *base = [current isKindOfClass:[NSArray class]] ? current : @[];
    NSArray *incoming = [delta isKindOfClass:[NSArray class]] ? delta : @[];
    return nWPSyncDedupeAndPrune([base arrayByAddingObjectsFromArray:incoming], now);
}

+ (NSArray<NSDictionary *> *)clearPopups {
    return @[];
}

@end
