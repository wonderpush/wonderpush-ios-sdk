//
//  WPSyncDecision.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The pure-processor's decision for a single source's response block.
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-processor.ts (ProcessorDecision and
// FetchHint). The processor never touches storage/network: it returns this decision and the
// orchestrator applies it, in order:
//   1. Save newState (if set).
//   2. Plug-in callbacks: clearState, then applyData, then applyDelta.
//   3. Trigger the fetch (if set), echoing fetchHint on the explicit request.
//
// `applyData` / `applyDelta` may legitimately be set to null/empty (e.g. the "no data exists"
// reset), so each has a companion `hasX` flag to distinguish "set to null" from "not set".

#import <Foundation/Foundation.h>
#import "WPSyncSourceState.h"

NS_ASSUME_NONNULL_BEGIN

/// The known* head-hint subset echoed back to the server on the explicit fetch request.
@interface WPSyncFetchHint : NSObject
@property (nonatomic, strong, nullable) NSNumber *knownVersion;
@property (nonatomic, strong, nullable) id knownVersionId;     // NSNumber | NSString | nil
@property (nonatomic, strong, nullable) NSNumber *knownReadDate;
/// Minimal dictionary, omitting unset fields.
- (NSDictionary *)toDictionary;
@end

@interface WPSyncDecision : NSObject

/// The state to persist; nil means "no state change". (Serialized under the JSON key "newState";
/// named `nextState` here to avoid ARC's `new`-prefix ownership rule.)
@property (nonatomic, strong, nullable) WPSyncSourceState *nextState;
/// Call the plug-in's clearState() (currently only on empty-reset).
@property (nonatomic, assign) BOOL clearState;

@property (nonatomic, assign) BOOL hasApplyData;
@property (nonatomic, strong, nullable) id applyData;          // applied before delta
@property (nonatomic, assign) BOOL hasApplyDelta;
@property (nonatomic, strong, nullable) id applyDelta;

/// @"weak" (debounced) or @"firm"; nil means no fetch.
@property (nonatomic, copy, nullable) NSString *triggerFetch;
/// The head hint to echo on the explicit request; set only for known*-triggered fetches.
@property (nonatomic, strong, nullable) WPSyncFetchHint *fetchHint;

/// Minimal dictionary matching the JS decision shape (omits unset fields). Used by the
/// conformance harness for deep-equality against the vectors' `expected`.
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
