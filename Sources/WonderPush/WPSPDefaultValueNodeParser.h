//
//  WPSPDefaultValueNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPConfigurableValueNodeParser.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPDefaultValueNodeParser : WPSPConfigurableValueNodeParser

+ (NSDate * _Nullable) parseAbsoluteDate:(NSString *)input;

@end

NS_ASSUME_NONNULL_END
