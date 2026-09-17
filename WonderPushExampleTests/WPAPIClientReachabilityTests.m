//
//  WPAPIClientReachabilityTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPBaseAPIClient.computeReachability. Ports the mapping from
// wonderpush-android-sdk@803adfb3 (WonderPushRequestParamsDecorator.computeReachability): no device
// token -> optOut; else optIn iff both the app-level toggle and the last-known OS permission are on,
// softOptOut otherwise.

#import <XCTest/XCTest.h>
#import "WPAPIClient.h"
#import "WPConfiguration.h"

@interface WPAPIClientReachabilityTests : XCTestCase
@end

@implementation WPAPIClientReachabilityTests {
    NSString *_savedDeviceToken;
    BOOL _savedNotificationEnabled;
    BOOL _savedCachedOsNotificationEnabled;
}

- (void)setUp {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    _savedDeviceToken = config.deviceToken;
    _savedNotificationEnabled = config.notificationEnabled;
    _savedCachedOsNotificationEnabled = config.cachedOsNotificationEnabled;
}

- (void)tearDown {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    [config setDeviceToken:_savedDeviceToken];
    config.notificationEnabled = _savedNotificationEnabled;
    config.cachedOsNotificationEnabled = _savedCachedOsNotificationEnabled;
}

- (void)testNoDeviceTokenIsOptOut {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    [config setDeviceToken:nil];
    config.notificationEnabled = YES;
    config.cachedOsNotificationEnabled = YES;
    XCTAssertEqualObjects([WPBaseAPIClient computeReachability], @"optOut");
}

- (void)testAppEnabledAndOsEnabledIsOptIn {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    [config setDeviceToken:@"token"];
    config.notificationEnabled = YES;
    config.cachedOsNotificationEnabled = YES;
    XCTAssertEqualObjects([WPBaseAPIClient computeReachability], @"optIn");
}

- (void)testAppDisabledWithTokenIsSoftOptOut {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    [config setDeviceToken:@"token"];
    config.notificationEnabled = NO;
    config.cachedOsNotificationEnabled = YES;
    XCTAssertEqualObjects([WPBaseAPIClient computeReachability], @"softOptOut");
}

- (void)testOsDisabledWithTokenIsSoftOptOut {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    [config setDeviceToken:@"token"];
    config.notificationEnabled = YES;
    config.cachedOsNotificationEnabled = NO;
    XCTAssertEqualObjects([WPBaseAPIClient computeReachability], @"softOptOut");
}

@end
