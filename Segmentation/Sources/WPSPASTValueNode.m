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


@implementation WPSPASTUnknownValueNode;

- (instancetype) initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value {
    if (self = [super initWithContext:context value:value]) {
        _key = key;
    }
    return self;
}

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitASTUnknownValueNode:self];
}

@end

@implementation WPSPNullValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitNullValueNode:self];
}

@end

@implementation WPSPBooleanValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitBooleanValueNode:self];
}

@end

@implementation WPSPNumberValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitNumberValueNode:self];
}

@end

@implementation WPSPStringValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitStringValueNode:self];
}

@end
