//
//  WPSyncProcessor.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The pure response processor for the sdk-sync channel (algorithm.md:214-243).
// Ported from wonderpush-javascript-sdk/src/wonderpush/sync-processor.ts. Returns *decisions* about
// what should happen (state change, plug-in callbacks, fetch triggers) and never touches storage,
// network, or the SDK. The orchestrator (issue .18) executes the decision.

#import <Foundation/Foundation.h>
#import "WPSyncResponseBlock.h"
#import "WPSyncSourceState.h"
#import "WPSyncDecision.h"

NS_ASSUME_NONNULL_BEGIN

/// Result of classifyResponse: which mode a response should run through.
@interface WPSyncResponseClassification : NSObject
/// @"opportunistic", @"explicit", or @"none".
@property (nonatomic, copy) NSString *mode;
/// Only set when mode == @"explicit": the source the top-level fields apply to.
@property (nonatomic, copy, nullable) NSString *explicitSource;
/// {"mode": …, "explicitSource"?: …} — for conformance comparison.
- (NSDictionary *)toDictionary;
@end

@interface WPSyncProcessor : NSObject

/// Decide whether a response should run through the processor, and how.
/// Opportunistic: POST /events, PATCH /installation. Explicit: GET on the 5 sync endpoints.
+ (WPSyncResponseClassification *)classifyResponsePath:(nullable NSString *)path
                                                method:(nullable NSString *)method;

/// Process one source's block. `block` nil means "no info" -> empty decision. `serverTime` nil means
/// absent. `mode` is @"opportunistic" or @"explicit".
+ (WPSyncDecision *)processSourceBlock:(nullable WPSyncResponseBlock *)block
                            serverTime:(nullable NSNumber *)serverTime
                                 state:(WPSyncSourceState *)state
                                  mode:(NSString *)mode;

@end

NS_ASSUME_NONNULL_END
