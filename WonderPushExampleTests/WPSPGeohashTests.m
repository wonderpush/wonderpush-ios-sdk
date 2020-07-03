//
//  WPSPGeohashTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 03/07/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPGeohash.h"
#import "WPSPGeoLocation.h"

@interface WPSPGeohashTests : XCTestCase
@property (nonatomic, strong) NSString *geohash;
@property (assign) double delta;
@property (assign) double top;
@property (assign) double right;
@property (assign) double bottom;
@property (assign) double left;
@property (assign) double centerLat;
@property (assign) double centerLon;
@end

@implementation WPSPGeohashTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.geohash = @"ezs42";
    self.delta = 1e-3;
    self.top = 42.627;
    self.right = -5.581;
    self.bottom = 42.583;
    self.left = -5.625;
    self.centerLat = 42.605;
    self.centerLon = -5.603;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGeohash {
    WPSPGeohash *parsed = [WPSPGeohash parse:self.geohash];
    XCTAssertTrue([parsed isKindOfClass:WPSPGeohash.class]);
    XCTAssertEqualObjects(parsed.geohash, self.geohash);

    XCTAssertGreaterThan(parsed.top, parsed.bottom);
    XCTAssertGreaterThan(parsed.right, parsed.left);

    XCTAssertEqualWithAccuracy(parsed.top, self.top, self.delta);
    XCTAssertEqualWithAccuracy(parsed.right, self.right, self.delta);
    XCTAssertEqualWithAccuracy(parsed.bottom, self.bottom, self.delta);
    XCTAssertEqualWithAccuracy(parsed.left, self.left, self.delta);

    XCTAssertLessThan(parsed.centerLat, parsed.top);
    XCTAssertGreaterThan(parsed.centerLat, parsed.bottom);
    XCTAssertEqualWithAccuracy(parsed.centerLat, self.centerLat, self.delta);
    XCTAssertLessThan(parsed.centerLon, parsed.right);
    XCTAssertGreaterThan(parsed.centerLon, parsed.left);
    XCTAssertEqualWithAccuracy(parsed.centerLon, self.centerLon, self.delta);
}
- (void)testGeoLocation {
    WPSPGeohash *parsed = [WPSPGeohash parse:self.geohash];

    WPSPGeoLocation *topLeft = parsed.topLeft;
    XCTAssertTrue([topLeft isKindOfClass:WPSPGeoLocation.class]);
    XCTAssertEqualWithAccuracy(topLeft.lat, self.top, self.delta);
    XCTAssertEqualWithAccuracy(topLeft.lon, self.left, self.delta);

    WPSPGeoLocation *topRight = parsed.topRight;
    XCTAssertTrue([topRight isKindOfClass:WPSPGeoLocation.class]);
    XCTAssertEqualWithAccuracy(topRight.lat, self.top, self.delta);
    XCTAssertEqualWithAccuracy(topRight.lon, self.right, self.delta);

    WPSPGeoLocation *bottomLeft = parsed.bottomLeft;
    XCTAssertTrue([bottomLeft isKindOfClass:WPSPGeoLocation.class]);
    XCTAssertEqualWithAccuracy(bottomLeft.lat, self.bottom, self.delta);
    XCTAssertEqualWithAccuracy(bottomLeft.lon, self.left, self.delta);

    WPSPGeoLocation *bottomRight = parsed.bottomRight;
    XCTAssertTrue([bottomRight isKindOfClass:WPSPGeoLocation.class]);
    XCTAssertEqualWithAccuracy(bottomRight.lat, self.bottom, self.delta);
    XCTAssertEqualWithAccuracy(bottomRight.lon, self.right, self.delta);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
