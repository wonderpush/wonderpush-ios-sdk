//
//  WPSPMatchAllCriterionNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPMatchAllCriterionNode.h"

@implementation WPSPMatchAllCriterionNode

- (id)accept:(id<WPSPASTCriterionVisitor>)visitor {
    return [visitor visitMatchAllCriterionNode:self];
}
@end
