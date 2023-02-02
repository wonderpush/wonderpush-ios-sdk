//
//  WPSwiftInterop.m
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WonderPush_private.h"
#import "WPSwiftInterop.h"

// ObjC implementation of WonderPushPrivateProtocol, that will be exposed to Swift using WonderPushObjCInterop
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@implementation WonderPushPrivate

// The ObjC runtime will call this method automatically.
// We register this class with WonderPushObjCInterop to expose it to Swift as a WonderPushPrivateProtocol implementation.
+ (void)load {
    [WonderPushObjCInterop registerWonderPushPrivate:[WonderPushPrivate class]];
}

- (void)trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback {
    [WonderPush trackInternalEvent:type eventData:data customData:customData sentCallback:sentCallback];
}

@end
