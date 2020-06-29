//
//  WPSPFieldPath.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPFieldPath.h"

@implementation WPSPFieldPath

- (instancetype)initWithParts:(NSArray<NSString *> *)parts {
    if (self = [super init]) {
        _parts = parts;
    }
    return self;
}

+ (WPSPFieldPath *)pathByParsing:(NSString *)dottedPath {
    return [[WPSPFieldPath alloc] initWithParts:[dottedPath componentsSeparatedByString:@"."]];
}
@end
