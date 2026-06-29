//
//  WPSyncStateStore.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncStateStore.h"
#import <WonderPushCommon/WPLog.h>

// Single NSUserDefaults key holding {storageKey: stateDict}. The `__wonderpush_` prefix keeps it
// inside the SDK's namespace (picked up by WPConfiguration's state dump / clear logic).
static NSString * const kWPSyncStateUserDefaultsKey = @"__wonderpush_syncStatePerProfile";

@interface WPSyncStateStore ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation WPSyncStateStore

+ (instancetype)defaultStore {
    // A shared singleton so the @synchronized(self) read-modify-write guard actually serializes
    // concurrent writes from different sources to the single shared NSUserDefaults blob. (A per-call
    // factory would lock on distinct instances and let writes interleave -> last-writer-wins.)
    static WPSyncStateStore *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[WPSyncStateStore alloc] initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    });
    return shared;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    if (self = [super init]) {
        _userDefaults = userDefaults;
    }
    return self;
}

+ (NSString *)storageKeyForSource:(NSString *)source userId:(NSString *)userId deviceId:(NSString *)deviceId {
    NSString *uid = (userId.length > 0) ? userId : @"";   // null/empty both collapse to "" (JS `userId || ''`)
    return [NSString stringWithFormat:@"sync:%@:%@:%@", source ?: @"", uid, deviceId ?: @""];
}

#pragma mark - root blob (JSON-as-NSData, like WPConfiguration)

- (NSDictionary *)rootDictionary {
    id raw = [self.userDefaults objectForKey:kWPSyncStateUserDefaultsKey];
    if ([raw isKindOfClass:[NSData class]]) {
        id json = [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];
        return [json isKindOfClass:[NSDictionary class]] ? json : nil;
    }
    if ([raw isKindOfClass:[NSDictionary class]]) return raw;   // tolerate a plain dict if ever written
    return nil;
}

- (void)writeRootDictionary:(NSDictionary *)root {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:&error];
    if (data) {
        [self.userDefaults setObject:data forKey:kWPSyncStateUserDefaultsKey];
        [self.userDefaults synchronize];
    } else {
        WPLog(@"WPSyncStateStore: failed to serialize sync state; not persisted: %@", error);
    }
}

#pragma mark - load / save

- (WPSyncSourceState *)loadSource:(NSString *)source userId:(NSString *)userId deviceId:(NSString *)deviceId {
    @synchronized (self) {
        NSString *key = [WPSyncStateStore storageKeyForSource:source userId:userId deviceId:deviceId];
        id stateDict = [self rootDictionary][key];
        if ([stateDict isKindOfClass:[NSDictionary class]]) {
            return [WPSyncSourceState stateWithDictionary:stateDict];
        }
        return [WPSyncSourceState emptyState];
    }
}

- (void)saveState:(WPSyncSourceState *)state forSource:(NSString *)source userId:(NSString *)userId deviceId:(NSString *)deviceId {
    @synchronized (self) {
        NSMutableDictionary *root = [[self rootDictionary] mutableCopy] ?: [NSMutableDictionary new];
        NSString *key = [WPSyncStateStore storageKeyForSource:source userId:userId deviceId:deviceId];
        root[key] = [state toDictionary];
        [self writeRootDictionary:root];
    }
}

@end
