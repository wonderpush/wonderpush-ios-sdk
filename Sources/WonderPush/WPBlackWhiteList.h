//
//  WPBlackWhiteList.h
//  WonderPush
//
//  Created by Stéphane JAIS on 05/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPBlackWhiteList : NSObject
@property (nonatomic, nonnull, readonly) NSArray<NSString *> * blackList;
@property (nonatomic, nonnull, readonly) NSArray<NSString *> * whiteList;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype) initWithRules:(NSArray<NSString *> *)rules NS_DESIGNATED_INITIALIZER;

- (BOOL)allow:(NSString *)item;

+ (BOOL)item:(NSString *)item matches:(NSString *)rule;

@end

NS_ASSUME_NONNULL_END
