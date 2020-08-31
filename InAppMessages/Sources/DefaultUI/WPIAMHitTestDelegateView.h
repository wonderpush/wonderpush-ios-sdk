//
//  WPIAMHitTestDelegateView.h
//  WonderPush
//
//  Created by Stéphane JAIS on 31/08/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WPIAMHitTestDelegate <NSObject>
- (BOOL)pointInside:(CGPoint)point view:(UIView *)view withEvent:(UIEvent *)event;
@end

@interface WPIAMHitTestDelegateView : UIView
@property (nullable, nonatomic, weak) id<WPIAMHitTestDelegate> pointInsideDelegate;
@end

NS_ASSUME_NONNULL_END
