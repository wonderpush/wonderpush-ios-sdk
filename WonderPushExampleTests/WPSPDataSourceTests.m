//
//  WPSPDataSourceTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 06/07/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPDataSource.h"

@interface WPSPDataSourceTests : XCTestCase

@end

@implementation WPSPDataSourceTests

- (void) testDataSource {
    // it should produce good source names
    NSArray <NSString *> *parts = @[@"foo", @"bar"];
    XCTAssertEqualObjects(@"user.foo.bar", [[WPSPFieldSource alloc] initWithParent:[WPSPUserSource new] fieldPath:[[WPSPFieldPath alloc] initWithParts:parts]].name);
    XCTAssertEqualObjects(@"installation.foo.bar", [[WPSPFieldSource alloc] initWithParent:[WPSPInstallationSource new] fieldPath:[[WPSPFieldPath alloc] initWithParts:parts]].name);
    XCTAssertEqualObjects(@"installation.foo.bar", [[WPSPFieldSource alloc] initWithParent:[[WPSPFieldSource alloc] initWithParent:[WPSPInstallationSource new] fieldPath:[[WPSPFieldPath alloc] initWithParts:@[@"foo"]]] fieldPath:[[WPSPFieldPath alloc] initWithParts:@[@"bar"]]].name);
    XCTAssertEqualObjects(@"event.foo.bar", [[WPSPFieldSource alloc] initWithParent:[WPSPEventSource new] fieldPath:[[WPSPFieldPath alloc] initWithParts:parts]].name);
    XCTAssertEqualObjects(@"lastActivityDate", [[WPSPLastActivityDateSource alloc] initWithParent:nil].name);
    XCTAssertEqualObjects(@"presence.sinceDate", [[WPSPPresenceSinceDateSource alloc] initWithParent:[WPSPInstallationSource new] present:false].name);
    XCTAssertEqualObjects(@"presence.elapsedTime", [[WPSPPresenceElapsedTimeSource alloc] initWithParent:[WPSPInstallationSource new] present:false].name);
    XCTAssertEqualObjects(@"geo.location", [[WPSPGeoLocationSource alloc] initWithParent:[WPSPInstallationSource new]].name);
    XCTAssertEqualObjects(@"geo.date", [[WPSPGeoDateSource alloc] initWithParent:[WPSPInstallationSource new]].name);
}

- (void)testFullPath {
    // it should get fullPath
    WPSPFieldPath *fullPath = [[[WPSPFieldSource alloc] initWithParent:[[WPSPFieldSource alloc] initWithParent:[WPSPInstallationSource new] fieldPath:[[WPSPFieldPath alloc] initWithParts:@[@"a", @"b"]]] fieldPath:[[WPSPFieldPath alloc] initWithParts:@[@"c", @"d"]]] fullPath];
    
    NSArray *expectedParts = @[@"a", @"b", @"c", @"d"];
    XCTAssertEqualObjects(fullPath.parts, expectedParts);
}
@end
