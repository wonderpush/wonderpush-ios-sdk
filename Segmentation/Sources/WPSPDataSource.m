//
//  WPDataSource.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPDataSource.h"

@implementation WPSPDataSource

- (instancetype) initWithParent:(WPSPDataSource *)parent {
    if (self = [super init]) {
        _parent = parent;
    }
    return self;
}

- (NSString *)name {
    @throw @"abstract";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    @throw @"abstract";
}

- (WPSPDataSource *)rootDataSource {
    if (self.parent) return self.parent.rootDataSource;
    return self;
}

@end

@implementation WPSPInstallationSource
- (instancetype)init {
    return [super initWithParent:nil];
}

- (NSString *)name {
    return @"installation";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitInstallationSource:self];
}
@end

@implementation WPSPUserSource
- (instancetype)init {
    return [super initWithParent:nil];
}

- (NSString *)name {
    return @"user";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitUserSource:self];
}
@end

@implementation WPSPEventSource
- (instancetype)init {
    return [super initWithParent:nil];
}

- (NSString *)name {
    return @"event";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitEventSource:self];
}
@end

@implementation WPSPFieldSource

- (instancetype)initWithParent:(WPSPDataSource *)parent fieldPath:(WPSPFieldPath *)path {
    if (self = [super initWithParent:parent]) {
        _path = path;
    }
    return self;
}

- (NSString *)name {
    return [NSString stringWithFormat:@"%@.%@", self.parent.name, [self.path.parts componentsJoinedByString:@"."]];
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitFieldSource:self];
}

- (WPSPFieldPath *)fullPath {
    WPSPDataSource *currentDataSource = self;
    NSArray <NSString *> *parts = [NSArray new];
    while (currentDataSource) {
        if ([currentDataSource isKindOfClass:WPSPFieldSource.class]) {
            WPSPFieldSource *currentFieldSource = (WPSPFieldSource *)currentDataSource;
            parts = [currentFieldSource.path.parts arrayByAddingObjectsFromArray:parts];
        }
        currentDataSource = currentDataSource.parent;
    }
    return [[WPSPFieldPath alloc] initWithParts:parts];
}
@end

@implementation WPSPGeoDateSource

- (NSString *)name {
    return @"geo.date";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitGeoDateSource:self];
}

@end

@implementation WPSPGeoLocationSource

- (NSString *)name {
    return @"geo.location";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitGeoLocationSource:self];
}
@end

@implementation WPSPLastActivityDateSource

- (NSString *)name {
    return @"lastActivityDate";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitLastActivityDateSource:self];
}

@end

@implementation WPSPPresenceElapsedTimeSource

- (instancetype)initWithParent:(WPSPInstallationSource *)parent present:(BOOL)present {
    if (self = [super initWithParent:parent]) {
        _present = present;
    }
    return self;
}

- (NSString *)name {
    return @"presence.elapsedTime";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitPresenceElapsedTimeSource:self];
}

@end

@implementation WPSPPresenceSinceDateSource

- (instancetype)initWithParent:(WPSPInstallationSource *)parent present:(BOOL)present {
    if (self = [super initWithParent:parent]) {
        _present = present;
    }
    return self;
}

- (NSString *)name {
    return @"presence.sinceDate";
}

- (id)accept:(id<WPSPDataSourceVisitor>)visitor {
    return [visitor visitPresenceSinceDateSource:self];
}

@end
