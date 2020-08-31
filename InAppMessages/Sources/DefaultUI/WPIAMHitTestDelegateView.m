//
//  WPIAMHitTestDelegateView.m
//  WonderPush
//
//  Created by Stéphane JAIS on 31/08/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPIAMHitTestDelegateView.h"


@implementation WPIAMHitTestDelegateView
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.pointInsideDelegate) return [self.pointInsideDelegate pointInside:point view:self withEvent:event];
    return [super pointInside:point withEvent:event];
}

@end
