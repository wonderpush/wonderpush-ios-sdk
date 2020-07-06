//
//  WPSPGeoBoxTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 06/07/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPGeoBox.h"

static const double top = 1;
static const double right = 2;
static const double bottom = 3;
static const double left = 4;

@interface WPSPGeoBoxTests : XCTestCase
@property (nonnull, strong) WPSPGeoLocation *topRight;
@property (nonnull, strong) WPSPGeoLocation *topLeft;
@property (nonnull, strong) WPSPGeoLocation *bottomRight;
@property (nonnull, strong) WPSPGeoLocation *bottomLeft;
@end

@implementation WPSPGeoBoxTests

- (void)setUp {
    self.topRight = [[WPSPGeoLocation alloc] initWithLat:top lon:right];
    self.topLeft = [[WPSPGeoLocation alloc] initWithLat:top lon:left];
    self.bottomRight = [[WPSPGeoLocation alloc] initWithLat:bottom lon:right];
    self.bottomLeft = [[WPSPGeoLocation alloc] initWithLat:bottom lon:left];
}

- (void)testFromTopRightBottomLeft {
    // it should construct fromTopRightBottomLeft properly
    WPSPGeoBox *instance = [[WPSPGeoBox alloc] initWithTop:top right:right bottom:bottom left:left];
    XCTAssertEqual(top, instance.top);
    XCTAssertEqual(right, instance.right);
    XCTAssertEqual(bottom, instance.bottom);
    XCTAssertEqual(left, instance.left);
}
@end
