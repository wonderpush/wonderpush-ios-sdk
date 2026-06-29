//
//  WPSyncKnobsProvider.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncKnobsProvider.h"
#import "WPSyncKnobs.h"
#import "WPRemoteConfig.h"

@interface WPSyncKnobsProvider ()
@property (nonatomic, strong) WPRemoteConfigManager *manager;
@end

@implementation WPSyncKnobsProvider

+ (WPSyncKnobs *)knobsFromRemoteConfig:(WPRemoteConfig *)config {
    NSDictionary *data = [config.data isKindOfClass:[NSDictionary class]] ? config.data : nil;
    return [WPSyncKnobs mergeKnobsFromDefaults:[WPSyncKnobs defaultKnobs] remoteConfig:data];
}

- (instancetype)initWithRemoteConfigManager:(WPRemoteConfigManager *)manager {
    if (self = [super init]) {
        _manager = manager;
    }
    return self;
}

- (void)readKnobs:(void (^)(WPSyncKnobs *))completion {
    [self.manager read:^(WPRemoteConfig *config, NSError *error) {
        completion([WPSyncKnobsProvider knobsFromRemoteConfig:(error ? nil : config)]);
    }];
}

@end
