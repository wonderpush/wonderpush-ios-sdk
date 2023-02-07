//
//  WPSwiftInterop.m
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

#import "WPSwiftInterop.h"

#import <Foundation/Foundation.h>

#import "WonderPush_private.h"
#import "WPConfiguration.h"
#import "WPJsonSyncLiveActivity.h"

// ObjC implementation of WonderPushPrivateProtocol, that will be exposed to Swift using WonderPushObjCInterop
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@implementation WonderPushPrivate

// The ObjC runtime will call this method automatically.
// We register this class with WonderPushObjCInterop to expose it to Swift as a WonderPushPrivateProtocol implementation.
+ (void)load {
    [WonderPushObjCInterop registerWonderPushPrivate:[WonderPushPrivate class]];
    // Let's register other classes for Swift here too
    [WonderPushObjCInterop registerWPJsonSyncLiveActivity:[WPJsonSyncLiveActivity class]];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *) liveActivityIdsPerAttributesTypeName {
    return [[WPConfiguration sharedConfiguration] liveActivitySyncActivityIdsPerAttributesTypeName];
}

- (void)trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback {
    [WonderPush trackInternalEvent:type eventData:data customData:customData sentCallback:sentCallback];
}

@end
