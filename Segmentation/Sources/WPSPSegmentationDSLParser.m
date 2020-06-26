//
//  WPSegmentationDSLParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPSegmentationDSLParser.h"

@implementation WPSPSegmentationDSLParser
- (instancetype) initWithParserConfig:(WPSPParserConfig *)parserConfig {
    if (self = [super init]) {
        _parserConfig = parserConfig;
    }
    return self;
}

@end
