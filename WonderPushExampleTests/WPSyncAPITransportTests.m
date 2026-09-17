//
//  WPSyncAPITransportTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncAPITransport (issue wonderpush-ios-sdk-i2x.16/.18): it forwards the GET to the
// injected sender with the right userId/path/params and maps the response (error -> success BOOL).

#import <XCTest/XCTest.h>
#import "WPSyncAPITransport.h"

@interface WPSyncAPITransportTests : XCTestCase
@end

@implementation WPSyncAPITransportTests

- (void)testForwardsToSenderAndReportsSuccessOnNoError {
    __block NSString *gotUserId = nil, *gotPath = nil; __block NSDictionary *gotParams = nil;
    WPSyncAPITransport *t = [[WPSyncAPITransport alloc] initWithSender:
        ^(NSString *userId, NSString *path, NSDictionary *params, WPSyncAPIResponseHandler handler) {
            gotUserId = userId; gotPath = path; gotParams = params;
            handler(@{@"_serverTime": @1}, nil);   // success: a response, no error
        }];
    __block BOOL success = NO, called = NO;
    [t fetchSource:@"contact" userId:@"alice" path:@"/sync/contact" params:@{@"lastVersion": @5}
        completion:^(BOOL s) { success = s; called = YES; }];
    XCTAssertTrue(called);
    XCTAssertTrue(success);
    XCTAssertEqualObjects(gotUserId, @"alice");
    XCTAssertEqualObjects(gotPath, @"/sync/contact");
    XCTAssertEqualObjects(gotParams[@"lastVersion"], @5);
}

- (void)testReportsFailureOnError {
    WPSyncAPITransport *t = [[WPSyncAPITransport alloc] initWithSender:
        ^(NSString *userId, NSString *path, NSDictionary *params, WPSyncAPIResponseHandler handler) {
            handler(nil, [NSError errorWithDomain:@"test" code:1 userInfo:nil]);
        }];
    __block BOOL success = YES, called = NO;
    [t fetchSource:@"contact" userId:nil path:@"/sync/contact" params:@{} completion:^(BOOL s) { success = s; called = YES; }];
    XCTAssertTrue(called);
    XCTAssertFalse(success);
}

@end
