//
//  WPSyncAPITransport.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncAPITransport.h"

@interface WPSyncAPITransport ()
@property (nonatomic, copy) WPSyncAPIRequestSender sender;
@end

@implementation WPSyncAPITransport

- (instancetype)initWithSender:(WPSyncAPIRequestSender)sender {
    if (self = [super init]) {
        _sender = [sender copy];
    }
    return self;
}

- (void)fetchSource:(NSString *)source userId:(NSString *)userId path:(NSString *)path
             params:(NSDictionary *)params completion:(void (^)(BOOL))completion {
    self.sender(userId, path, params, ^(id response, NSError *error) {
        // Success = a completed HTTP call with no error. The response body itself is applied by the
        // incoming interceptor; the fetch loop only needs this to reset/keep its failure count.
        if (completion) completion(error == nil);
    });
}

@end
