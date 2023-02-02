//
//  WPSwiftInterop.m
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSwiftInterop.h"

// ObjC implementation of WonderPushPrivateProtocol, that will be exposed to Swift using WonderPushObjCInterop
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@implementation WPSwiftInterop

// The ObjC runtime will call this method automatically.
// We register this class with WonderPushObjCInterop to expose it to Swift as a WonderPushPrivateProtocol implementation.
+ (void)load {
    [WonderPushObjCInterop registerWonderPushPrivate:[WPSwiftInterop class]];
}

- (void)doSomethingInternalWithSecretAttribute:(NSInteger)attribute {
    NSLog(@"INTERNAL METHOD CALLED WITH SUCCESS %ld", (long)attribute);
}

@end
