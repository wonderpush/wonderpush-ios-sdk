//
//  WPSyncManager.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncManager.h"
#import "WPSync.h"
#import "WPSyncStateStore.h"
#import "WPSyncFetcher.h"
#import "WPSyncKnobs.h"
#import "WPSyncKnobsProvider.h"
#import "WPSyncContactSource.h"
#import "WPSyncPopupsSource.h"
#import "WPSyncRequestObserver.h"
#import "WPRemoteConfig.h"

@interface WPSyncManager ()
@property (nonatomic, strong) WPSync *sync;
@property (nonatomic, strong) WPSyncKnobs *cachedKnobs;
@property (nonatomic, assign) BOOL stackBuilt;
@property (nonatomic, assign) BOOL installed;
@end

@implementation WPSyncManager

+ (instancetype)sharedManager {
    static WPSyncManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [WPSyncManager new]; });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _cachedKnobs = [WPSyncKnobs defaultKnobs];
    }
    return self;
}

- (void)refreshWithRemoteConfigManager:(WPRemoteConfigManager *)remoteConfigManager
                   identifiersProvider:(NSDictionary *(^)(void))identifiersProvider
                                sender:(WPSyncAPIRequestSender)sender {
    [self buildStackIfNeededWithIdentifiersProvider:identifiersProvider sender:sender];
    __weak typeof(self) weakSelf = self;
    [remoteConfigManager read:^(WPRemoteConfig *config, NSError *error) {
        typeof(self) self2 = weakSelf;
        if (!self2) return;
        WPRemoteConfig *effective = error ? nil : config;
        self2.cachedKnobs = [WPSyncKnobsProvider knobsFromRemoteConfig:effective];
        // Master gate: only go live when the server explicitly enables sync (default off -> inert).
        BOOL enabled = [effective.data[@"syncEnabled"] boolValue];
        if (enabled && !self2.installed) {
            [WPSyncHook installObserver:self2.sync];
            self2.installed = YES;
        } else if (!enabled && self2.installed) {
            [WPSyncHook installObserver:nil];
            self2.installed = NO;
        }
    }];
}

- (id)dataForSource:(NSString *)source {
    return [self.sync dataForSource:source];   // nil-safe: self.sync is nil until the stack is built
}

- (void)buildStackIfNeededWithIdentifiersProvider:(NSDictionary *(^)(void))identifiersProvider
                                           sender:(WPSyncAPIRequestSender)sender {
    if (self.stackBuilt) return;
    self.stackBuilt = YES;

    WPSyncStateStore *store = [WPSyncStateStore defaultStore];
    WPSyncAPITransport *transport = [[WPSyncAPITransport alloc] initWithSender:sender];
    WPSyncFetcher *fetcher = [[WPSyncFetcher alloc] initWithStateStore:store transport:transport];

    WPSync *sync = [[WPSync alloc] initWithStateStore:store fetcher:fetcher];
    sync.identifiersProvider = identifiersProvider;
    __weak typeof(self) weakSelf = self;
    sync.knobsProvider = ^WPSyncKnobs *{ typeof(self) s = weakSelf; return s ? s.cachedKnobs : [WPSyncKnobs defaultKnobs]; };

    [sync registerSource:@"contact" plugin:[WPSyncContactSource new]];
    [sync registerSource:@"popups" plugin:[WPSyncPopupsSource new]];
    self.sync = sync;
}

@end
