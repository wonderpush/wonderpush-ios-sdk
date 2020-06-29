//
//  WPSPAndCriterionNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPAndCriterionNode.h"
#import "WPSPASTCriterionVisitor.h"
@implementation WPSPAndCriterionNode

- (instancetype)initWithContext:(WPSPParsingContext *)context children:(NSArray<WPSPASTCriterionNode *> *)children {
    if (self = [super initWithContext:context]) {
        _children = [NSArray arrayWithArray:children];
    }
    return self;
}

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitAndCriterionNode:self];
}
@end
