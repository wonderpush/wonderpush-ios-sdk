//
//  WPSyncRequestObserver.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncRequestObserver.h"

@implementation WPSyncHook

static id<WPSyncRequestObserver> sInstalledObserver;

+ (void)installObserver:(id<WPSyncRequestObserver>)observer {
    @synchronized (self) {
        sInstalledObserver = observer;
    }
}

+ (id<WPSyncRequestObserver>)observer {
    @synchronized (self) {
        return sInstalledObserver;
    }
}

@end
