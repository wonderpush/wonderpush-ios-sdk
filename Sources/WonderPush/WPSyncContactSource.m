//
//  WPSyncContactSource.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncContactSource.h"
#import "WPSyncContactStore.h"
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"

static NSString * const kSource = @"contact";

@interface WPSyncContactSource ()
@property (nonatomic, strong) WPSyncStateStore *stateStore;
@property (nonatomic, copy) NSDictionary *(^identifiersProvider)(void);
@end

@implementation WPSyncContactSource

- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore
                identifiersProvider:(NSDictionary *(^)(void))identifiersProvider {
    if (self = [super init]) {
        _stateStore = stateStore;
        _identifiersProvider = [identifiersProvider copy];
    }
    return self;
}

#pragma mark - WPSyncSourcePlugin

- (void)applyData:(id)data {
    [self updateDataWith:^NSDictionary *(NSDictionary *current) {
        return [WPSyncContactStore applyContactData:current data:data];
    }];
}

- (void)applyDelta:(id)delta {
    [self updateDataWith:^NSDictionary *(NSDictionary *current) {
        return [WPSyncContactStore applyContactDelta:current delta:delta];
    }];
}

- (void)clearState {
    [self updateDataWith:^NSDictionary *(NSDictionary *current) {
        return [WPSyncContactStore clearContact];
    }];
}

#pragma mark - helper

/// Load the contact state under the current profile, replace its `data` via `transform`, and save.
- (void)updateDataWith:(NSDictionary *_Nullable (^)(NSDictionary *_Nullable current))transform {
    NSDictionary *ids = self.identifiersProvider() ?: @{};
    NSString *userId = ids[@"userId"];
    NSString *deviceId = ids[@"deviceId"];
    if (![deviceId isKindOfClass:[NSString class]] || deviceId.length == 0) return;   // deviceId invariant

    WPSyncSourceState *state = [self.stateStore loadSource:kSource userId:userId deviceId:deviceId];
    NSDictionary *current = [state.data isKindOfClass:[NSDictionary class]] ? state.data : nil;
    state.data = transform(current);
    [self.stateStore saveState:state forSource:kSource userId:userId deviceId:deviceId];
}

@end
