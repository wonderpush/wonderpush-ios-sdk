//
//  WPSyncKnobsProvider.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Bridges WPRemoteConfig to the sdk-sync knobs (issue .13): reads the `sync*` keys from the remote
// config and merges them over DEFAULT_KNOBS (honoring the opportunistic-injection kill switch),
// falling back to defaults when there is no config or no override. The merge itself lives in
// WPSyncKnobs (mergeKnobsFromDefaults:remoteConfig:); this type only sources the config blob.

#import <Foundation/Foundation.h>

@class WPSyncKnobs, WPRemoteConfig, WPRemoteConfigManager;

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncKnobsProvider : NSObject

/// Effective knobs for a given remote config (nil config -> DEFAULT_KNOBS). Pure.
+ (WPSyncKnobs *)knobsFromRemoteConfig:(nullable WPRemoteConfig *)config;

- (instancetype)initWithRemoteConfigManager:(WPRemoteConfigManager *)manager NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Read the current remote config via the manager and hand back the effective knobs. On error or no
/// config, returns DEFAULT_KNOBS.
- (void)readKnobs:(void (^)(WPSyncKnobs *knobs))completion;

@end

NS_ASSUME_NONNULL_END
