//
//  WPSyncMutex.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncMutex.h"

@implementation WPSyncMutex {
    NSLock *_guard;   // protects _held; held only for the brief flag check/flip
    BOOL _held;
}

+ (instancetype)mutexNamed:(NSString *)name {
    static NSMutableDictionary<NSString *, WPSyncMutex *> *registry;
    static NSLock *registryLock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registry = [NSMutableDictionary new];
        registryLock = [NSLock new];
    });
    [registryLock lock];
    WPSyncMutex *mutex = registry[name];
    if (!mutex) {
        mutex = [WPSyncMutex new];
        registry[name] = mutex;
    }
    [registryLock unlock];
    return mutex;
}

- (instancetype)init {
    if (self = [super init]) {
        _guard = [NSLock new];
        _held = NO;
    }
    return self;
}

- (BOOL)tryLock {
    [_guard lock];
    BOOL acquired = !_held;
    if (acquired) _held = YES;
    [_guard unlock];
    return acquired;
}

- (void)unlock {
    [_guard lock];
    _held = NO;
    [_guard unlock];
}

@end
