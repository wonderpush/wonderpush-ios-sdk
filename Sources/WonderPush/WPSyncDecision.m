//
//  WPSyncDecision.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncDecision.h"

@implementation WPSyncFetchHint

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (self.knownVersion != nil) dict[@"knownVersion"] = self.knownVersion;
    if (self.knownVersionId != nil) dict[@"knownVersionId"] = self.knownVersionId;
    if (self.knownReadDate != nil) dict[@"knownReadDate"] = self.knownReadDate;
    return dict;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p: %@>", NSStringFromClass(self.class), self, [self toDictionary]];
}

@end

@implementation WPSyncDecision

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (self.nextState != nil) dict[@"newState"] = [self.nextState toDictionary];
    if (self.clearState) dict[@"clearState"] = @YES;
    if (self.hasApplyData) dict[@"applyData"] = self.applyData ?: [NSNull null];
    if (self.hasApplyDelta) dict[@"applyDelta"] = self.applyDelta ?: [NSNull null];
    if (self.triggerFetch != nil) dict[@"triggerFetch"] = self.triggerFetch;
    if (self.fetchHint != nil) dict[@"fetchHint"] = [self.fetchHint toDictionary];
    if (self.continuePaging) dict[@"continuePaging"] = @YES;
    return dict;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p: %@>", NSStringFromClass(self.class), self, [self toDictionary]];
}

@end
