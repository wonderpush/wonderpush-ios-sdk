//
//  WPSync.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The sdk-sync orchestrator (issue .18). Ported from the WonderPushSDK._protected.Sync coordinator in
// wonderpush-javascript-sdk/src/wonderpush/sync.js. It ties the pieces together:
//
//   - registerSource:plugin:  — declare a source and its apply/clear callbacks.
//   - prepareOutgoingParams… — build the params to inject on opportunistic requests (WPSyncOutgoing).
//   - consumeIncomingResponse… — classify a response, run the processor per source, execute the
//     decision (save state, run plug-in callbacks, trigger fetches), then max-age forcing.
//   - dataForSource: — the synced payload, for the segmentation/popup engines (issues .26/.27).
//
// Dependencies (state store, fetcher) are injected, and the current identifiers / knobs / clock are
// supplied via block providers, so the whole coordinator is unit-testable with fakes. The thin hooks
// that call prepareOutgoingParams/consumeIncomingResponse from WPBaseAPIClient (and the Measurements
// client) are issues .14/.15/.25; the real WPAPIClient transport adapter is wired here at SDK init.
//
// Per-source response processing is serialized (load->process->save->callbacks under a per-source
// lock) so two responses for the same source can't interleave and clobber state.

#import <Foundation/Foundation.h>

@class WPSyncStateStore, WPSyncKnobs;
@protocol WPSyncFetching;

NS_ASSUME_NONNULL_BEGIN

/// A source's optional callbacks, invoked by the processor's decision (clearState, then applyData,
/// then applyDelta). All optional — a source may register with no plugin (state-only).
@protocol WPSyncSourcePlugin <NSObject>
@optional
- (void)clearState;
- (void)applyData:(nullable id)data;
- (void)applyDelta:(nullable id)delta;
@end

@interface WPSync : NSObject

- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore
                           fetcher:(id<WPSyncFetching>)fetcher NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Current identifiers: a dict with optional userId/deviceId/installationId/visitorId. Default: empty.
@property (nonatomic, copy) NSDictionary *(^identifiersProvider)(void);
/// Effective knobs. Default: WPSyncKnobs.defaultKnobs.
@property (nonatomic, copy) WPSyncKnobs *(^knobsProvider)(void);
/// Current time in ms. Default: real wall clock.
@property (nonatomic, copy) long long (^nowProvider)(void);

- (void)registerSource:(NSString *)name plugin:(nullable id<WPSyncSourcePlugin>)plugin;
- (NSArray<NSString *> *)registeredSources;

/// Params to merge onto an outgoing request (empty unless the path/method is opportunistic and the
/// kill switch is on). Safe to call on any request.
- (NSDictionary *)prepareOutgoingParamsForPath:(nullable NSString *)path method:(nullable NSString *)method;

/// Process an API response: classify, run the processor per source, execute decisions, force fetches.
/// Best-effort and never raises; a non-opportunistic/explicit response is a no-op.
- (void)consumeIncomingResponseForPath:(nullable NSString *)path
                                method:(nullable NSString *)method
                              response:(nullable NSDictionary *)response;

/// The synced payload for a source under the current profile (nil if none). For local segmentation.
- (nullable id)dataForSource:(NSString *)source;

@end

NS_ASSUME_NONNULL_END
