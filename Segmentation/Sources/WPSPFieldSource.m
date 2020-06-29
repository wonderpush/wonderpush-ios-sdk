//
//  WPSPFieldSource.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPFieldSource.h"

@implementation WPSPFieldSource

- (instancetype)initWithParent:(WPSPDataSource *)parent fieldPath:(WPSPFieldPath *)path {
    if (self = [super initWithParent:parent]) {
        _path = path;
    }
    return self;
}
@end
