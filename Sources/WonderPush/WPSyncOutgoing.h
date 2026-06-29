//
//  WPSyncOutgoing.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Pure helpers for sdk-sync outgoing-param injection (issue .14).
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-outgoing.ts. Spec: algorithm.md:84-91.
//
// The SDK piggybacks per-source sync state onto opportunistic API calls (POST /events and
// PATCH /installation). This file builds the params dict; the request-layer hook that gathers the
// current identifiers + registered-source state and merges the result onto the request lives with
// the orchestrator (issue .18) and covers BOTH the SDK API and the Measurements API.
//
// Path matching is HOST-AGNOSTIC by suffix so it covers both `/v1/events` (SDK API) and
// `https://measurements-api.wonderpush.com/v1/events` (Measurements API), per the spec.

#import <Foundation/Foundation.h>

@class WPSyncSourceState;

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncOutgoing : NSObject

/// Whether sync params may be injected onto this request — true exactly for the opportunistic
/// endpoints (POST /events, PATCH /installation). Method matters: a GET /installation (the explicit
/// fetch) must NOT get opportunistic injection. Mirrors WPSyncProcessor's classifier by delegating to it.
+ (BOOL)shouldInjectForPath:(nullable NSString *)path method:(nullable NSString *)method;

/// Build the params to inject. `identifiers` is a dict with optional keys userId/deviceId/
/// installationId/visitorId (NEVER contactId — the server resolves it). `statePerSource` maps a
/// source name to its WPSyncSourceState. Emits _sync<Id> identifier keys and _<source>Sync.* state
/// keys; lastSyncMeta is JSON-encoded; lastSyncMeta/lastVersionId omitted when nil.
+ (NSDictionary *)buildOutgoingParamsWithIdentifiers:(NSDictionary *)identifiers
                                      statePerSource:(NSDictionary<NSString *, WPSyncSourceState *> *)statePerSource;

@end

NS_ASSUME_NONNULL_END
