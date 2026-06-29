//
//  WPSyncOutgoingTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncOutgoing (issue wonderpush-ios-sdk-i2x.14, pure builder): the inject-path
// predicate and the outgoing-params builder (identifiers + per-source state, contactId never sent).

#import <XCTest/XCTest.h>
#import "WPSyncOutgoing.h"
#import "WPSyncSourceState.h"

@interface WPSyncOutgoingTests : XCTestCase
@end

@implementation WPSyncOutgoingTests

#pragma mark - shouldInjectForPath

- (void)testShouldInjectForPath {
    // Opportunistic endpoints: POST /events and PATCH /installation (host-agnostic).
    XCTAssertTrue([WPSyncOutgoing shouldInjectForPath:@"/events" method:@"POST"]);
    XCTAssertTrue([WPSyncOutgoing shouldInjectForPath:@"/v1/events" method:@"POST"]);
    XCTAssertTrue([WPSyncOutgoing shouldInjectForPath:@"/installation" method:@"PATCH"]);
    XCTAssertTrue([WPSyncOutgoing shouldInjectForPath:@"https://measurements-api.wonderpush.com/v1/events" method:@"POST"]);

    // Right path, WRONG method -> NO. Crucially the explicit GET /installation fetch is not injected.
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:@"/installation" method:@"GET"]);
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:@"/events" method:@"GET"]);
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:@"/installation" method:@"PUT"]);

    // Nested paths / other endpoints -> NO.
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:@"/v1/events/123" method:@"POST"]);
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:@"/configuration" method:@"GET"]);
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:@"" method:@"POST"]);
    XCTAssertFalse([WPSyncOutgoing shouldInjectForPath:nil method:@"POST"]);
}

#pragma mark - buildOutgoingParams: identifiers

- (void)testIdentifiersEmittedUnderSyncKeysAndEmptySkipped {
    NSDictionary *p = [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:@{
        @"userId": @"alice", @"deviceId": @"D1", @"installationId": @"", @"visitorId": @"V1",
    } statePerSource:@{}];
    XCTAssertEqualObjects(p[@"_syncUserId"], @"alice");
    XCTAssertEqualObjects(p[@"_syncDeviceId"], @"D1");
    XCTAssertNil(p[@"_syncInstallationId"]);   // empty string skipped
    XCTAssertEqualObjects(p[@"_syncVisitorId"], @"V1");
}

- (void)testContactIdIsNeverEmitted {
    NSDictionary *p = [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:@{
        @"userId": @"alice", @"contactId": @42,
    } statePerSource:@{}];
    XCTAssertNil(p[@"_syncContactId"]);
    for (NSString *key in p) {
        XCTAssertEqual([key rangeOfString:@"ontactId"].location, (NSUInteger)NSNotFound, @"contactId leaked in %@", key);
    }
}

#pragma mark - buildOutgoingParams: per-source state

- (void)testPerSourceStateEmitted {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastSyncDate = 111; s.lastVersion = 222; s.lastReadDate = 333;
    s.lastVersionId = @"v9";
    s.lastSyncMeta = @{@"syncVersion": @0};
    NSDictionary *p = [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:@{} statePerSource:@{@"contact": s}];

    XCTAssertEqualObjects(p[@"_contactSync.lastSyncDate"], @111);
    XCTAssertEqualObjects(p[@"_contactSync.lastVersion"], @222);
    XCTAssertEqualObjects(p[@"_contactSync.lastReadDate"], @333);
    XCTAssertEqualObjects(p[@"_contactSync.lastVersionId"], @"v9");
    id meta = [NSJSONSerialization JSONObjectWithData:[p[@"_contactSync.lastSyncMeta"] dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0 error:nil];
    XCTAssertEqualObjects(meta, (@{@"syncVersion": @0}));
}

- (void)testPerSourceNullablesOmittedWhenNil {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];   // nil meta, nil versionId
    s.lastVersion = 5;
    NSDictionary *p = [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:@{} statePerSource:@{@"user": s}];
    XCTAssertEqualObjects(p[@"_userSync.lastVersion"], @5);
    XCTAssertEqualObjects(p[@"_userSync.lastSyncDate"], @0);    // int64 trio always present
    XCTAssertNil(p[@"_userSync.lastSyncMeta"]);                 // nil meta omitted
    XCTAssertNil(p[@"_userSync.lastVersionId"]);                // nil versionId omitted
}

- (void)testMultipleSourcesNamespacedIndependently {
    WPSyncSourceState *c = [WPSyncSourceState emptyState]; c.lastVersion = 1;
    WPSyncSourceState *u = [WPSyncSourceState emptyState]; u.lastVersion = 2;
    NSDictionary *p = [WPSyncOutgoing buildOutgoingParamsWithIdentifiers:@{} statePerSource:@{@"contact": c, @"user": u}];
    XCTAssertEqualObjects(p[@"_contactSync.lastVersion"], @1);
    XCTAssertEqualObjects(p[@"_userSync.lastVersion"], @2);
}

@end
