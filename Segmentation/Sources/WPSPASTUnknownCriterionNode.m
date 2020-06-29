//
//  WPSPASTUnknownCriterionNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPASTUnknownCriterionNode.h"

@implementation WPSPASTUnknownCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value {
    if (self = [super initWithContext:context]) {
        _key = key;
        _value = value;
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitASTUnknownCriterionNode:self];
}

@end
