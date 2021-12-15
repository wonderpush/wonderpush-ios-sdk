//
//  WPSPDataSourceVisitor.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class WPSPUserSource;
@class WPSPInstallationSource;
@class WPSPEventSource;
@class WPSPFieldSource;
@class WPSPLastActivityDateSource;
@class WPSPPresenceSinceDateSource;
@class WPSPPresenceElapsedTimeSource;
@class WPSPGeoLocationSource;
@class WPSPGeoDateSource;

@protocol WPSPDataSourceVisitor <NSObject>
- (id) visitUserSource:(WPSPUserSource *)dataSource;
- (id) visitInstallationSource:(WPSPInstallationSource *)dataSource;
- (id) visitEventSource:(WPSPEventSource *)dataSource;
- (id) visitFieldSource:(WPSPFieldSource *)dataSource;
- (id) visitLastActivityDateSource:(WPSPLastActivityDateSource *)dataSource;
- (id) visitPresenceSinceDateSource:(WPSPPresenceSinceDateSource *)dataSource;
- (id) visitPresenceElapsedTimeSource:(WPSPPresenceElapsedTimeSource *)dataSource;
- (id) visitGeoLocationSource:(WPSPGeoLocationSource *)dataSource;
- (id) visitGeoDateSource:(WPSPGeoDateSource *)dataSource;
@end

NS_ASSUME_NONNULL_END
