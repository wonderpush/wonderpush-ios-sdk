//
//  WPIAMCappingDefinition.h
//  WonderPush
//
//  Created by Stéphane JAIS on 15/09/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMCappingDefinition : NSObject
@property(nonatomic, readonly) NSInteger maxImpressions;
@property(nonatomic, readonly) NSTimeInterval snoozeTime; // In seconds
- (instancetype) initWithMaxImpressions:(NSInteger)maxImpressions snoozeTime:(NSTimeInterval)snoozeTime;
+ (instancetype) defaultCapping;
@end

NS_ASSUME_NONNULL_END
