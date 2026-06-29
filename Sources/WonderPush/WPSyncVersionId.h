//
//  WPSyncVersionId.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Leaf-level pure predicates for the sdk-sync response processor.
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-versionid.ts.
//   - versionId total order: sdk-sync/docs/docs/sync/algorithm.md:259-264
//   - acceptance check:      sdk-sync/docs/docs/sync/algorithm.md:224-227
//
// No dependency on the other sync types — this mirrors the JS leaf module (no imports), so it
// stays trivially testable in isolation. A "VersionId" is NSNumber | NSString | nil, with NSNull
// also treated as the null-missing sentinel (the conformance vectors encode null as JSON null).

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncVersionId : NSObject

/// Total order for mixed-type version identifiers: null/missing < int64 < string.
/// Numbers compare naturally; strings compare byte-wise UTF-8, case-sensitive.
/// nil and NSNull are both the null-missing sentinel and compare equal to each other.
/// Returns NSOrderedAscending (-1) / NSOrderedSame (0) / NSOrderedDescending (1).
+ (NSComparisonResult)compareVersionId:(nullable id)a with:(nullable id)b;

/// Decide whether to apply a payload-bearing response to local state. Two branches:
///   (a) monotonic — strictly newer (version, versionId, readDate) tuple, or
///   (b) empty-reset — version == 0 && data is {} or [] && readDate > lastReadDate.
/// Callers must only invoke this on responses that carry data and/or delta.
+ (BOOL)acceptsResponseWithVersion:(long long)version
                         versionId:(nullable id)versionId
                          readDate:(long long)readDate
                              data:(nullable id)data
                       lastVersion:(long long)lastVersion
                     lastVersionId:(nullable id)lastVersionId
                      lastReadDate:(long long)lastReadDate;

/// True iff data is {} (empty object) or [] (empty array). Used by the empty-reset detection.
+ (BOOL)isEmptyDataPayload:(nullable id)data;

@end

NS_ASSUME_NONNULL_END
