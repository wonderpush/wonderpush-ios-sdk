//
//  WPSyncVersionId.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncVersionId.h"
#import <string.h>

/// nil and NSNull are both the null-missing sentinel.
static BOOL WPSyncVersionIdMissing(id _Nullable v) {
    return v == nil || v == [NSNull null];
}

@implementation WPSyncVersionId

+ (NSComparisonResult)compareVersionId:(id)a with:(id)b {
    BOOL aMissing = WPSyncVersionIdMissing(a);
    BOOL bMissing = WPSyncVersionIdMissing(b);
    if (aMissing && bMissing) return NSOrderedSame;
    if (aMissing) return NSOrderedAscending;   // null < anything non-null
    if (bMissing) return NSOrderedDescending;

    BOOL aIsNumber = [a isKindOfClass:[NSNumber class]];
    BOOL bIsNumber = [b isKindOfClass:[NSNumber class]];
    if (aIsNumber && !bIsNumber) return NSOrderedAscending;   // int64 < string (arbitrary, per spec)
    if (!aIsNumber && bIsNumber) return NSOrderedDescending;

    if (aIsNumber && bIsNumber) {
        long long x = [(NSNumber *)a longLongValue];
        long long y = [(NSNumber *)b longLongValue];
        if (x < y) return NSOrderedAscending;
        if (x > y) return NSOrderedDescending;
        return NSOrderedSame;
    }

    // Both strings: byte-wise UTF-8, case-sensitive (algorithm.md:264).
    const char *sa = [(NSString *)a UTF8String];
    const char *sb = [(NSString *)b UTF8String];
    int c = strcmp(sa, sb);
    if (c < 0) return NSOrderedAscending;
    if (c > 0) return NSOrderedDescending;
    return NSOrderedSame;
}

+ (BOOL)acceptsResponseWithVersion:(long long)version
                         versionId:(id)versionId
                          readDate:(long long)readDate
                              data:(id)data
                       lastVersion:(long long)lastVersion
                     lastVersionId:(id)lastVersionId
                      lastReadDate:(long long)lastReadDate {
    // Branch (a): monotonic.
    if (version > lastVersion) return YES;
    if (version == lastVersion) {
        NSComparisonResult cmp = [self compareVersionId:versionId with:lastVersionId];
        if (cmp == NSOrderedDescending) return YES;
        if (cmp == NSOrderedSame && readDate > lastReadDate) return YES;
    }
    // Branch (b): empty-reset — server affirms no data for the current identifier set.
    if (version == 0 && [self isEmptyDataPayload:data] && readDate > lastReadDate) {
        return YES;
    }
    return NO;
}

/// True iff data is {} (empty object) or [] (empty array).
+ (BOOL)isEmptyDataPayload:(id)data {
    if ([data isKindOfClass:[NSArray class]]) return [(NSArray *)data count] == 0;
    if ([data isKindOfClass:[NSDictionary class]]) return [(NSDictionary *)data count] == 0;
    return NO;
}

@end
