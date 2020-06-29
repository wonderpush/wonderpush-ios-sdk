//
//  WPSPFieldPath.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSPFieldPath : NSObject
@property (nonnull, readonly) NSArray<NSString *> *parts;

- (instancetype) initWithParts:(NSArray<NSString *> *)parts;

+ (WPSPFieldPath * _Nonnull) pathByParsing:(NSString *)dottedPath;
@end

NS_ASSUME_NONNULL_END
