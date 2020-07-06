//
//  WPSPParsingContextTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 06/07/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPParsingContext.h"
#import "WPSPSegmentationDSLParser.h"
#import "WPSPDataSource.h"

@interface WPSPParsingContextTests : XCTestCase

@end

@implementation WPSPParsingContextTests

- (void)testWithDataSource {
    // it should construct a child context for withDataSource
    WPSPParsingContext *contextRoot = [[WPSPParsingContext alloc] initWithParser:[WPSPSegmentationDSLParser defaultParser] parentContext:nil dataSource:[[WPSPInstallationSource alloc] initWithParent:nil]];
    XCTAssertNil(contextRoot.parentContext);
    XCTAssertTrue([contextRoot.dataSource isKindOfClass:WPSPInstallationSource.class]);
    
    WPSPParsingContext *contextChild = [contextRoot withDataSource:[[WPSPEventSource alloc] initWithParent:nil]];
    XCTAssertEqual(contextRoot, contextChild.parentContext);
    XCTAssertTrue([contextChild.dataSource isKindOfClass:WPSPEventSource.class]);
    WPSPParsingContext *contextGrandChild = [contextChild
                                             withDataSource:[[WPSPFieldSource alloc]
                                                             initWithParent:contextChild.dataSource
                                                             fieldPath:[[WPSPFieldPath alloc] initWithParts:@[@"a", @"b"]]]];
    XCTAssertEqual(contextChild, contextGrandChild.parentContext);
    XCTAssertTrue([contextGrandChild.dataSource isKindOfClass:WPSPFieldSource.class]);
}

@end
