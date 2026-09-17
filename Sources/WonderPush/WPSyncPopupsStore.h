//
//  WPSyncPopupsStore.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Multi-object store transforms for the `popups` source (issue .23). Ported from
// wonderpush-javascript-sdk/src/wonderpush/sync-popups-store.ts. TRANSPORT ONLY — this stores the
// synced popup-rule list; feeding it into the in-app engine is a separate follow-up (issue .27).
//
// Multi-object semantics (distinct from the single-object contact store — NO deep-merge/WPJsonUtil;
// items are full objects replaced wholesale by id):
//   - data  -> full reset:  replace the stored list with the server's full list (sent only when
//              lastVersion==0). Deduped by id (highest updateDate wins) and pruned of expired items.
//   - delta -> merge:       an ARRAY OF FULL OBJECTS upserted into the stored list by id, favoring the
//              highest updateDate. Soft-deletes (status=="deleted") are retained as tombstones until
//              their expirationDate.
//   - clear -> wipe:        drop all stored items (empty-reset / identifier change).
//
// Each item carries: id (string, unique), updateDate (int64 — the item's "version"), status
// ("active"/"deleted"), expirationDate (int64 — after which the item, INCLUDING a tombstone, may be
// hard-deleted). `now` is injected (server-adjusted ms) so expiry is deterministic in tests. First-seen
// order is preserved; display ordering/precedence is the engine's concern (issue .27), not done here.
// NOTE: the JS reference does NOT apply the maxPopupsEntries knob or reorder in this store — neither
// does this port (faithful to sync-popups-store.ts / sync-popups.js).

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncPopupsStore : NSObject

/// Full reset: the stored list becomes the server's full list, deduped by id (highest updateDate wins)
/// and pruned of items whose expirationDate < now. A non-array payload yields an empty list.
+ (NSArray<NSDictionary *> *)resetPopupsData:(nullable id)data now:(long long)now;

/// Merge: upsert the array of full objects in `delta` into `current` by id favoring the highest
/// updateDate; retain tombstones until expiry; prune expired. A non-array delta is a no-op merge
/// (the current list, pruned). A non-array current is treated as empty.
+ (NSArray<NSDictionary *> *)applyPopupsDelta:(nullable id)current delta:(nullable id)delta now:(long long)now;

/// Wipe: drop all stored items (returns an empty list).
+ (NSArray<NSDictionary *> *)clearPopups;

@end

NS_ASSUME_NONNULL_END
