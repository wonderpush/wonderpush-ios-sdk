//
//  WPParsingContext.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPSegmentationDSLParser.h"
#import "WPSPDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPParsingContext : NSObject
@property (nonnull, readonly) WPSPSegmentationDSLParser *parser;
@property (nullable, readonly) WPSPParsingContext *parentContext;
@property (nonnull, readonly) WPSPDataSource *dataSource;

- (instancetype) initWithParser:(WPSPSegmentationDSLParser *)parser
                  parentContext:(WPSPParsingContext * _Nullable)parentContext
                     dataSource:(WPSPDataSource *)dataSource;

- (instancetype) withDataSource:(WPSPDataSource *)dataSource;
@end

NS_ASSUME_NONNULL_END
