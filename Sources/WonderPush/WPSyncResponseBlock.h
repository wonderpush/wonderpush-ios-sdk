//
//  WPSyncResponseBlock.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// A single source's response block. Same shape for the opportunistic path (nested under
// `_${source}Sync.…`) and the explicit path (at the response root).
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-processor.ts (the ResponseBlock
// interface). Representation: sdk-sync/docs/docs/sync/algorithm.md:169-179.
//
// Presence matters to the processor (a missing field differs from a field set to null), so the
// accessors distinguish "absent" (nil / hasX == NO) from an explicit JSON null (NSNull). Numeric
// fields are exposed as nullable NSNumber (nil == absent); the union fields (versionId, data,
// delta, knownVersionId) are exposed as `id` with a companion `hasX` flag.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncResponseBlock : NSObject

/// nil when the block itself is absent (no `_${source}Sync` key). An empty `{}` block yields a
/// non-nil instance whose `isEmpty` is YES.
+ (nullable instancetype)blockWithDictionary:(nullable NSDictionary *)dict;

/// YES when the block carries none of the recognized fields (the empty `{}` "try asking explicitly"
/// signal on the opportunistic path).
@property (nonatomic, readonly) BOOL isEmpty;

/// Opaque metadata blob (stored + echoed only). nil when absent.
@property (nonatomic, readonly, nullable) NSDictionary *meta;

@property (nonatomic, readonly, nullable) NSNumber *version;
@property (nonatomic, readonly) BOOL hasVersionId;
@property (nonatomic, readonly, nullable) id versionId;       // NSNumber | NSString | NSNull
@property (nonatomic, readonly, nullable) NSNumber *readDate;

@property (nonatomic, readonly) BOOL hasData;
@property (nonatomic, readonly, nullable) id data;             // full object or full list (or NSNull)
@property (nonatomic, readonly) BOOL hasDelta;
@property (nonatomic, readonly, nullable) id delta;            // partial patch or array of items

@property (nonatomic, readonly, nullable) NSNumber *knownVersion;
@property (nonatomic, readonly) BOOL hasKnownVersionId;
@property (nonatomic, readonly, nullable) id knownVersionId;   // NSNumber | NSString | NSNull
@property (nonatomic, readonly, nullable) NSNumber *knownReadDate;

@end

NS_ASSUME_NONNULL_END
