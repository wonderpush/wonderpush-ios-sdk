//
//  WPDataSource.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPDataSourceVisitor.h"
#import "WPSPFieldPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPDataSource : NSObject
@property (nullable, readonly) WPSPDataSource *parent;

- (instancetype) initWithParent:(WPSPDataSource * _Nullable)parent;
- (NSString *)name;
- (id)accept:(id<WPSPDataSourceVisitor>)visitor;
- (WPSPDataSource *)rootDataSource;
@end

@interface WPSPInstallationSource : WPSPDataSource
- (instancetype) init;
@end

@interface WPSPUserSource : WPSPDataSource
- (instancetype) init;
@end

@interface WPSPEventSource : WPSPDataSource
- (instancetype) init;
@end

@interface WPSPFieldSource : WPSPDataSource
@property (nonnull, readonly) WPSPFieldPath *path;

- (instancetype) initWithParent:(WPSPDataSource *)parent fieldPath:(WPSPFieldPath *)path;
- (WPSPFieldPath *)fullPath;
@end

@interface WPSPGeoDateSource : WPSPDataSource
@end

@interface WPSPGeoLocationSource : WPSPDataSource
@end

@interface WPSPLastActivityDateSource : WPSPDataSource
@end

@interface WPSPPresenceElapsedTimeSource : WPSPDataSource
@property (assign, readonly) BOOL present;

- (instancetype) initWithParent:(WPSPInstallationSource *)parent present:(BOOL)present;
@end

@interface WPSPPresenceSinceDateSource : WPSPDataSource
@property (assign, readonly) BOOL present;

- (instancetype) initWithParent:(WPSPInstallationSource *)parent present:(BOOL)present;
@end

NS_ASSUME_NONNULL_END
