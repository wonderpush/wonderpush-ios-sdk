//
//  WPSegmentationDSLParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPParserConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPSegmentationDSLParser : NSObject
@property (nonnull, readonly) WPSPParserConfig *parserConfig;

- (instancetype) initWithParserConfig:(WPSPParserConfig *)parserConfig;
@end

NS_ASSUME_NONNULL_END
