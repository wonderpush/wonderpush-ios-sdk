//
//  WPParsingContext.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPParsingContext.h"

@implementation WPSPParsingContext

- (instancetype) initWithParser:(WPSPSegmentationDSLParser *)parser parentContext:(WPSPParsingContext *)parentContext dataSource:(WPSPDataSource *)dataSource {
    if (self = [super init]) {
        _parser = parser;
        _parentContext = parentContext;
        _dataSource = dataSource;
    }
    return self;
}
- (instancetype) withDataSource:(WPSPDataSource *)dataSource {
    return [[WPSPParsingContext alloc] initWithParser:self.parser parentContext:self dataSource:dataSource];
}
@end
