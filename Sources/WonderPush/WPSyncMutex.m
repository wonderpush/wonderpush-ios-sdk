//
//  WPSyncMutex.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncMutex.h"

@implementation WPSyncMutex {
    NSLock *_guard;        // protects _held/_token; held only for the brief flag check/flip
    BOOL _held;
    NSUInteger _token;     // identifies the current acquisition; bumped on each successful tryLock
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
        _token = 0;
    }
    return self;
}

- (NSUInteger)tryLock {
    [_guard lock];
    NSUInteger token = 0;
    if (!_held) {
        _held = YES;
        if (++_token == 0) _token = ++_token;   // never hand out 0 (the "failed" sentinel) on wrap
        token = _token;
    }
    [_guard unlock];
    return token;
}

- (BOOL)unlock:(NSUInteger)token {
    [_guard lock];
    BOOL released = (_held && token != 0 && token == _token);
    if (released) _held = NO;
    [_guard unlock];
    return released;
}

@end
