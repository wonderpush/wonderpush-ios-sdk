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
    return [self initWithReason:nil];
}

- (instancetype) initWithReason:(NSString *)reason {
    return [super initWithName:@"WPSPBadInputException" reason:reason userInfo:nil];
}

@end

@implementation WPSPUnknownCriterionException

- (instancetype)init {
    return [self initWithReason:nil];
}

- (instancetype) initWithReason:(NSString *)reason {
    return [super initWithName:@"WPSPUnknownCriterionException" reason:reason userInfo:nil];
}

@end

@implementation WPSPUnknownValueException

- (instancetype)init {
    return [self initWithReason:nil];
}

- (instancetype) initWithReason:(NSString *)reason {
    return [super initWithName:@"WPSPUnknownValueException" reason:reason userInfo:nil];
}

@end

