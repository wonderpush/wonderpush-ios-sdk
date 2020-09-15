//
//  WPIAMCappingDefinition.m
//  WonderPush
//
//  Created by Stéphane JAIS on 15/09/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPIAMCappingDefinition.h"

@implementation WPIAMCappingDefinition
- (instancetype)initWithMaxImpressions:(NSInteger)maxImpressions snoozeTime:(NSTimeInterval)snoozeTime {
    if (self = [super init]) {
        _snoozeTime = snoozeTime;
        _maxImpressions = maxImpressions;
    }
    return self;
}

+ (instancetype)defaultCapping {
    return [[WPIAMCappingDefinition alloc] initWithMaxImpressions:1 snoozeTime:0];
}

@end
