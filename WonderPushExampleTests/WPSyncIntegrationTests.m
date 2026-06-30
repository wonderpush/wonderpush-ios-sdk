//
//  WPSyncIntegrationTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Contact-pilot integration tests (issue wonderpush-ios-sdk-i2x.20). Assembles the REAL stack —
// WPSync + WPSyncFetcher + WPSyncAPITransport + WPSyncStateStore + WPSyncContactSource — with only
// the network `sender` faked (the same seam SDK-init wires to WonderPush.requestForUser). The fake
// sender also feeds the GET response back through consumeIncomingResponse, mimicking the .15
// interceptor, so the full opportunistic + explicit + firm-hint-fetch loop runs deterministically.

#import <XCTest/XCTest.h>
#import "WPSync.h"
#import "WPSyncFetcher.h"
#import "WPSyncAPITransport.h"
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"
#import "WPSyncContactSource.h"
#import "WPSyncKnobs.h"

static NSString * const kSuite = @"com.wonderpush.test.syncintegration";

@interface WPSyncIntegrationTests : XCTestCase
@end

@implementation WPSyncIntegrationTests {
    NSUserDefaults *_defaults;
    WPSyncStateStore *_store;
    WPSync *_sync;
    NSMutableDictionary *_ids;
    // fake network
    NSInteger _getCount;
    NSString *_lastGetPath;
    NSDictionary *_getResponse;   // non-nil => the GET succeeds and returns this body; nil => offline error
}

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    _store = [[WPSyncStateStore alloc] initWithUserDefaults:_defaults];
    _ids = [@{@"userId": @"alice", @"deviceId": @"D1", @"installationId": @"I1"} mutableCopy];
    _getCount = 0; _getResponse = nil;

    __weak typeof(self) ws = self;
    WPSyncAPIRequestSender sender = ^(NSString *userId, NSString *path, NSDictionary *params, WPSyncAPIResponseHandler handler) {
        typeof(self) s = ws; if (!s) return;
        s->_getCount++; s->_lastGetPath = path;
        if (s->_getResponse) {
            [s->_sync consumeIncomingResponseForPath:path method:@"GET" response:s->_getResponse];   // mimic the .15 interceptor
            handler(s->_getResponse, nil);
        } else {
            handler(nil, [NSError errorWithDomain:@"offline" code:1 userInfo:nil]);
        }
    };
    WPSyncAPITransport *transport = [[WPSyncAPITransport alloc] initWithSender:sender];
    WPSyncFetcher *fetcher = [[WPSyncFetcher alloc] initWithStateStore:_store transport:transport];
    fetcher.nowProvider = ^long long{ return 1000000; };
    fetcher.scheduler = ^(double delayMs, dispatch_block_t block) { block(); };   // run immediately
    fetcher.randomProvider = ^double{ return 0.0; };

    _sync = [[WPSync alloc] initWithStateStore:_store fetcher:fetcher];
    _sync.identifiersProvider = ^NSDictionary *{ typeof(self) s = ws; return s->_ids; };
    _sync.nowProvider = ^long long{ return 1000000; };
    [_sync registerSource:@"contact" plugin:[WPSyncContactSource new]];
}

- (void)tearDown { [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite]; }

- (WPSyncSourceState *)contactStateFor:(NSString *)userId { return [_store loadSource:@"contact" userId:userId deviceId:@"D1"]; }

#pragma mark - opportunistic round-trip

- (void)testOutgoingInjectionThenIncomingApplyThenEchoesAdvancedCursor {
    NSDictionary *out1 = [_sync prepareOutgoingParamsForPath:@"/events" method:@"POST"];
    XCTAssertEqualObjects(out1[@"_syncUserId"], @"alice");
    XCTAssertEqualObjects(out1[@"_syncDeviceId"], @"D1");
    XCTAssertEqualObjects(out1[@"_contactSync.lastVersion"], @0);   // nothing synced yet

    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_serverTime": @6000,
        @"_contactSync": @{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"data": @{@"firstName": @"Bob"}},
    }];
    XCTAssertEqualObjects([_sync dataForSource:@"contact"], (@{@"firstName": @"Bob"}));

    // The next outgoing request echoes the advanced cursor so the server won't resend v200.
    NSDictionary *out2 = [_sync prepareOutgoingParamsForPath:@"/events" method:@"POST"];
    XCTAssertEqualObjects(out2[@"_contactSync.lastVersion"], @200);
    XCTAssertEqualObjects(out2[@"_contactSync.lastVersionId"], @"v200");
}

#pragma mark - firm head hint -> explicit fetch -> apply

- (void)testFirmHintTriggersExplicitFetchThatAppliesAndResetsBackoff {
    // The explicit GET /contact will return the full contact.
    _getResponse = @{@"version": @300, @"versionId": @"v300", @"readDate": @3000, @"data": @{@"firstName": @"Carol"}, @"_serverTime": @7000};
    // An opportunistic head hint above our cursor triggers the firm fetch.
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_contactSync": @{@"knownVersion": @300, @"knownVersionId": @"v300", @"knownReadDate": @3000},
    }];
    XCTAssertEqual(_getCount, 1);
    XCTAssertEqualObjects(_lastGetPath, @"/contact");
    XCTAssertEqualObjects([_sync dataForSource:@"contact"], (@{@"firstName": @"Carol"}));   // GET response applied
    XCTAssertEqual([self contactStateFor:@"alice"].lastFetchUnsuccessfulAttemptCount, 0);    // success reset backoff
}

#pragma mark - offline backoff

- (void)testOfflineFetchLeavesBackoffAndRateLimitsImmediateRetry {
    _getResponse = nil;   // offline: GET errors
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_contactSync": @{@"knownVersion": @300, @"knownVersionId": @"v300", @"knownReadDate": @3000},
    }];
    XCTAssertEqual(_getCount, 1);
    XCTAssertEqual([self contactStateFor:@"alice"].lastFetchUnsuccessfulAttemptCount, 1);   // failure kept

    // A second firm hint immediately is rate-limited (same now within minSourceFetchIntervalMs).
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_contactSync": @{@"knownVersion": @301, @"knownVersionId": @"v301", @"knownReadDate": @3001},
    }];
    XCTAssertEqual(_getCount, 1);   // not re-fetched (floored)
}

#pragma mark - profile isolation

- (void)testProfileSwitchKeepsContactsIsolated {
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_contactSync": @{@"version": @10, @"versionId": @"a", @"readDate": @1, @"data": @{@"name": @"Alice"}},
    }];
    XCTAssertEqualObjects([_sync dataForSource:@"contact"], (@{@"name": @"Alice"}));

    _ids[@"userId"] = @"bob";   // setUserId
    XCTAssertNil([_sync dataForSource:@"contact"]);   // bob has nothing yet
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_contactSync": @{@"version": @20, @"versionId": @"b", @"readDate": @2, @"data": @{@"name": @"Bob"}},
    }];
    XCTAssertEqualObjects([_sync dataForSource:@"contact"], (@{@"name": @"Bob"}));

    _ids[@"userId"] = @"alice";   // switch back -> alice's contact is intact
    XCTAssertEqualObjects([_sync dataForSource:@"contact"], (@{@"name": @"Alice"}));
}

@end
