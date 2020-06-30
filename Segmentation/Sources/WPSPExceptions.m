//
//  WPSPExceptions.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPExceptions.h"

@implementation WPSPException
@end

@implementation WPSPBadInputException
- (instancetype)init {
    return [super initWithName:@"WPSPBadInputException" reason:nil userInfo:nil];
}
@end

@implementation WPSPUnknownCriterionException
- (instancetype)init {
    return [super initWithName:@"WPSPUnknownCriterionException" reason:nil userInfo:nil];
}
@end

@implementation WPSPUnknownValueException
- (instancetype)init {
    return [super initWithName:@"WPSPUnknownValueException" reason:nil userInfo:nil];
}
@end

