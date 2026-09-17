//
//  WPSyncPopupsSource.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncPopupsSource.h"
#import "WPSyncPopupsStore.h"
#import "WPUtil.h"

@interface WPSyncPopupsSource ()
@property (nonatomic, copy) long long (^nowProvider)(void);
@end

@implementation WPSyncPopupsSource

- (instancetype)init {
    return [self initWithNowProvider:^long long{ return [WPUtil getServerDate]; }];
}

- (instancetype)initWithNowProvider:(long long (^)(void))nowProvider {
    if (self = [super init]) {
        _nowProvider = [nowProvider copy];
    }
    return self;
}

- (id)dataByApplyingData:(id)data toCurrentData:(id)currentData {
    return [WPSyncPopupsStore resetPopupsData:data now:self.nowProvider()];
}

- (id)dataByApplyingDelta:(id)delta toCurrentData:(id)currentData {
    return [WPSyncPopupsStore applyPopupsDelta:currentData delta:delta now:self.nowProvider()];
}

@end
