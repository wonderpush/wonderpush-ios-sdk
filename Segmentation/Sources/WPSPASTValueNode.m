//
//  WPSPASTValueNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPASTValueNode.h"

@implementation WPSPASTValueNode

- (instancetype) initWithContext:(WPSPParsingContext *)context value:(id)value {
    if (self = [super init]) {
        _context = context;
        _value = value;
    }
    return self;
}

- (id) accept:(id<WPSPASTValueVisitor>)visitor {
    @throw @"abstract";
}

@end
