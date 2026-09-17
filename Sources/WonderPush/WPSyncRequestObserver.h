//
//  WPSyncRequestObserver.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The seam between WPBaseAPIClient's request path and the sdk-sync channel (issues .14/.15).
// WPBaseAPIClient depends only on this tiny protocol + the install point — never on WPSync directly —
// and the hooks are nil-guarded: until an observer is installed (at SDK init), they are completely
// inert and the request path is unchanged.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WPSyncRequestObserver <NSObject>
/// Params to merge onto an outgoing request (empty unless opportunistic). Must not raise.
- (NSDictionary *)prepareOutgoingParamsForPath:(nullable NSString *)path method:(nullable NSString *)method;
/// Consume a successful response body (best-effort; must not raise).
- (void)consumeIncomingResponseForPath:(nullable NSString *)path
                                method:(nullable NSString *)method
                              response:(nullable NSDictionary *)response;
@end

/// Process-wide install point for the request observer. Nil (the default) => sync hooks are inert.
@interface WPSyncHook : NSObject
+ (void)installObserver:(nullable id<WPSyncRequestObserver>)observer;
+ (nullable id<WPSyncRequestObserver>)observer;
@end

NS_ASSUME_NONNULL_END
