//
//  WPASTCriterionNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPASTCriterionNode.h"

@implementation WPSPASTCriterionNode
- (instancetype) initWithContext:(WPSPParsingContext *)context {
    if (self = [super init]) {
        _context = context;
    }
    return self;
}

- (id) accept:(id<WPSPASTCriterionVisitor>)visitor {
    @throw @"abstract";
}
@end
