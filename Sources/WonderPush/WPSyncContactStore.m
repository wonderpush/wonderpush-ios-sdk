//
//  WPSyncContactStore.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncContactStore.h"
#import <WonderPushCommon/WPJsonUtil.h>

/// Deep, immutable copy of a JSON value (so the stored contact never aliases the response payload).
/// Leaves (NSString/NSNumber/NSNull) are immutable and returned as-is.
static id nWPSyncDeepCopy(id value) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        for (id key in value) out[key] = nWPSyncDeepCopy(value[key]);
        return [out copy];
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
        for (id element in value) [out addObject:nWPSyncDeepCopy(element)];
        return [out copy];
    }
    return value;
}

@implementation WPSyncContactStore

+ (NSDictionary *)applyContactData:(NSDictionary *)current data:(id)data {
    if (![data isKindOfClass:[NSDictionary class]]) return nil;
    return nWPSyncDeepCopy(data);
}

+ (NSDictionary *)applyContactDelta:(NSDictionary *)current delta:(id)delta {
    NSDictionary *base = [current isKindOfClass:[NSDictionary class]] ? current : @{};
    if ([delta isKindOfClass:[NSDictionary class]]) {
        return [WPJsonUtil merge:base with:delta nullFieldRemoves:YES];
    }
    return nWPSyncDeepCopy(base);
}

+ (NSDictionary *)clearContact {
    return nil;
}

@end
