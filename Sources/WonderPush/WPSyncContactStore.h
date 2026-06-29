//
//  WPSyncContactStore.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Single-object store transforms for the `contact` source (algorithm.md:333-336).
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-contact-store.ts.
//   - data  -> full reset: replace the stored object entirely (old fields dropped).
//   - delta -> patch:      deep-merge a partial object on top (null value deletes the key).
//   - clear -> wipe:       drop the stored object.
// The patch reuses the SDK's WPJsonUtil deep-merge with null-field-removes, so contact deltas
// behave exactly like installation-custom patches elsewhere in the SDK. (The JS injects a JsonMerge;
// on iOS we use WPJsonUtil directly, which returns the merged object rather than mutating in place.)

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncContactStore : NSObject

/// Full reset: the stored contact becomes (a deep copy of) `data`. Returns nil when `data` is not an
/// object. Previously stored fields not present in `data` are dropped — replace, not merge.
+ (nullable NSDictionary *)applyContactData:(nullable NSDictionary *)current data:(nullable id)data;

/// Patch: deep-merge `delta` on top of `current` (null in the delta deletes that key). When nothing
/// is stored yet, the delta is merged onto an empty object.
+ (nullable NSDictionary *)applyContactDelta:(nullable NSDictionary *)current delta:(nullable id)delta;

/// Wipe: drop the stored contact (returns nil).
+ (nullable NSDictionary *)clearContact;

@end

NS_ASSUME_NONNULL_END
