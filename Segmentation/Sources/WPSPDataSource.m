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
