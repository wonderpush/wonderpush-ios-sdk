//
//  WPSyncAPITransport.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The real WPSyncFetchTransport: issues the explicit-fetch GET through the SDK's request layer
// (issue .16/.18). The actual request call is injected as a `sender` block so this adapter stays
// unit-testable without the live API client; at SDK init the sender is wired to
// WonderPush.requestForUser:method:@"GET":resource:params:handler:.
//
// The GET's *response body* is processed by the incoming interceptor (issue .15) like any other
// response — this adapter only reports the HTTP success/failure the fetch loop needs for its
// backoff/failure-count bookkeeping.

#import <Foundation/Foundation.h>
#import "WPSyncFetcher.h"   // WPSyncFetchTransport

NS_ASSUME_NONNULL_BEGIN

/// The request layer's completion: a parsed JSON response (or nil) and an error (or nil).
typedef void (^WPSyncAPIResponseHandler)(id _Nullable response, NSError *_Nullable error);

/// Issues a GET for `userId` to `path` with `params`, invoking `handler` on completion.
/// In production this wraps WonderPush.requestForUser:method:resource:params:handler:.
typedef void (^WPSyncAPIRequestSender)(NSString *_Nullable userId, NSString *path,
                                       NSDictionary *params, WPSyncAPIResponseHandler handler);

@interface WPSyncAPITransport : NSObject <WPSyncFetchTransport>

- (instancetype)initWithSender:(WPSyncAPIRequestSender)sender NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
