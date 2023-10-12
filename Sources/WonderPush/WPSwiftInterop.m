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
#import <WonderPushCommon/WPLog.h>
#import "WPConfiguration.h"
#import "WPJsonSyncLiveActivity.h"

// ObjC implementation of WonderPushPrivateProtocol, that will be exposed to Swift using WonderPushObjCInterop
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@implementation WonderPushPrivate

// The ObjC runtime will call this method automatically.
// We register this class with WonderPushObjCInterop to expose it to Swift as a WonderPushPrivateProtocol implementation.
+ (void)load {
    // Here we use reflection to avoid a linker issue when archiving in Xcode (interestingly not when testing the application)
    // ld: Undefined symbols:
    //    _OBJC_CLASS_$_WonderPushObjCInterop, referenced from:
    //         in WonderPushObjC.o
    //  clang: error: linker command failed with exit code 1 (use -v to see invocation)
    Class WonderPushObjCInteropClass = NSClassFromString(@"WonderPushObjCInterop");

    [WonderPushObjCInteropClass registerWonderPushPrivate:[WonderPushPrivate class]];
    // Let's register other classes for Swift here too
    [WonderPushObjCInteropClass registerWPJsonSyncLiveActivity:[WPJsonSyncLiveActivity class]];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *) liveActivityIdsPerAttributesTypeName {
    return [[WPConfiguration sharedConfiguration] liveActivitySyncActivityIdsPerAttributesTypeName];
}

- (void)log:(NSString *)message {
    WPLog(@"%@", message);
}

- (void)logDebug:(NSString *)message {
    WPLogDebug(@"%@", message);
}

- (void)trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback {
    [WonderPush trackInternalEvent:type eventData:data customData:customData sentCallback:sentCallback];
}

@end
