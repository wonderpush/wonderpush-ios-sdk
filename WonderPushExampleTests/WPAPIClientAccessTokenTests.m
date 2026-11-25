//
//  WPAPIClientAccessTokenTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Regression tests for WPAPIClient.decorateRequestParams: the accessToken sent with a request must be
// the one of the user the request was issued for (request.userId), not the current user's.
// Otherwise a request queued for a previous user (e.g. the delayed installation PATCH of the anonymous
// user clearing its pushToken after setUserId) is applied to the newly signed-in user's installation.

#import <XCTest/XCTest.h>
#import "WPAPIClient.h"
#import "WPAnonymousAPIClient.h"
#import "WPConfiguration.h"

static NSString * const TEST_USER_ID = @"WPAPIClientAccessTokenTests-user";

@interface WPAPIClientAccessTokenTests : XCTestCase
@end

@implementation WPAPIClientAccessTokenTests {
    NSString *_savedUserId;
    NSString *_savedAccessToken;
    id _savedPerUserArchive;
}

- (void)setUp {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    _savedUserId = config.userId;
    _savedAccessToken = config.accessToken;
    _savedPerUserArchive = [[NSUserDefaults standardUserDefaults] objectForKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY];

    // Anonymous user with its own access token, then switch to a signed-in user with another one
    [config changeUserId:nil];
    [config setAccessToken:@"anonymous-access-token"];
    [config changeUserId:TEST_USER_ID];
    [config setAccessToken:@"user-access-token"];
}

- (void)tearDown {
    WPConfiguration *config = [WPConfiguration sharedConfiguration];
    [config changeUserId:_savedUserId];
    [config setAccessToken:_savedAccessToken];
    if (_savedPerUserArchive) {
        [[NSUserDefaults standardUserDefaults] setObject:_savedPerUserArchive forKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:USER_DEFAULTS_PER_USER_ARCHIVE_KEY];
    }
}

- (WPRequest *)requestForUserId:(NSString *)userId {
    WPRequest *request = [WPRequest new];
    request.userId = userId;
    request.method = @"PATCH";
    request.resource = @"/installation";
    request.params = @{@"body": @{@"pushToken": @{@"data": [NSNull null]}}};
    return request;
}

- (void)testCurrentUserRequestUsesCurrentUserAccessToken {
    NSDictionary *params = [[WPAPIClient sharedClient] decorateRequestParams:[self requestForUserId:TEST_USER_ID]];
    XCTAssertEqualObjects(params[@"accessToken"], @"user-access-token");
}

- (void)testPreviousUserRequestUsesPreviousUserAccessToken {
    // A request issued for the anonymous user, executed after switching to TEST_USER_ID
    NSDictionary *params = [[WPAPIClient sharedClient] decorateRequestParams:[self requestForUserId:nil]];
    XCTAssertEqualObjects(params[@"accessToken"], @"anonymous-access-token");
}

- (void)testOtherUserRequestDoesNotUseCurrentUserAccessToken {
    // A user without any known access token must not borrow the current user's
    NSDictionary *params = [[WPAPIClient sharedClient] decorateRequestParams:[self requestForUserId:@"WPAPIClientAccessTokenTests-unknown"]];
    XCTAssertNil(params[@"accessToken"]);
}

// WPAnonymousAPIClient identifies the user with a userId parameter instead of an accessToken,
// and must likewise use the request's user rather than the current one.

- (void)testAnonymousClientPreviousUserRequestUsesRequestUserId {
    // A request issued for the anonymous user, executed after switching to TEST_USER_ID
    NSDictionary *params = [[WPAnonymousAPIClient sharedClient] decorateRequestParams:[self requestForUserId:nil]];
    XCTAssertEqualObjects(params[@"userId"], @"");
}

- (void)testAnonymousClientCurrentUserRequestUsesRequestUserId {
    NSDictionary *params = [[WPAnonymousAPIClient sharedClient] decorateRequestParams:[self requestForUserId:TEST_USER_ID]];
    XCTAssertEqualObjects(params[@"userId"], TEST_USER_ID);
}

@end
