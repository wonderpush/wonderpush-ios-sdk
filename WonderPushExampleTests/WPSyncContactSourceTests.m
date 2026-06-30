//
//  WPSyncContactSourceTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Tests for WPSyncContactSource (issue wonderpush-ios-sdk-i2x.19): the plug-in's apply/delta/clear
// persistence, and an end-to-end path through the WPSync orchestrator (response -> plugin -> store ->
// dataForSource).

#import <XCTest/XCTest.h>
#import "WPSyncContactSource.h"
#import "WPSync.h"
#import "WPSyncFetcher.h"      // WPSyncFetching
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"
#import "WPSyncKnobs.h"
#import "WPSyncDecision.h"     // WPSyncFetchHint

static NSString * const kSuite = @"com.wonderpush.test.contactsource";

@interface NoopFetching : NSObject <WPSyncFetching>
@end
@implementation NoopFetching
- (void)fetchSource:(NSString *)source userId:(NSString *)userId deviceId:(NSString *)deviceId
        identifiers:(NSDictionary *)identifiers knobs:(WPSyncKnobs *)knobs weak:(BOOL)weak
               hint:(WPSyncFetchHint *)hint completion:(void (^)(BOOL))completion {}
@end

@interface WPSyncContactSourceTests : XCTestCase
@end

@implementation WPSyncContactSourceTests {
    NSUserDefaults *_defaults;
    WPSyncStateStore *_store;
    WPSyncContactSource *_source;
    NSDictionary *(^_ids)(void);
}

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    _store = [[WPSyncStateStore alloc] initWithUserDefaults:_defaults];
    _ids = ^NSDictionary *{ return @{@"userId": @"alice", @"deviceId": @"D1"}; };
    _source = [[WPSyncContactSource alloc] initWithStateStore:_store identifiersProvider:_ids];
}

- (void)tearDown { [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite]; }

- (id)contactData { return [_store loadSource:@"contact" userId:@"alice" deviceId:@"D1"].data; }

#pragma mark - plug-in directly

- (void)testApplyDataSetsContact {
    [_source applyData:@{@"firstName": @"Alice", @"age": @30}];
    XCTAssertEqualObjects([self contactData], (@{@"firstName": @"Alice", @"age": @30}));
}

- (void)testApplyDeltaMergesOntoCurrent {
    [_source applyData:@{@"firstName": @"Alice"}];
    [_source applyDelta:@{@"lastName": @"Smith"}];
    XCTAssertEqualObjects([self contactData], (@{@"firstName": @"Alice", @"lastName": @"Smith"}));
}

- (void)testDeltaNullRemovesField {
    [_source applyData:@{@"firstName": @"Alice", @"nickname": @"Al"}];
    [_source applyDelta:@{@"nickname": [NSNull null]}];
    XCTAssertEqualObjects([self contactData], (@{@"firstName": @"Alice"}));
}

- (void)testClearStateWipes {
    [_source applyData:@{@"firstName": @"Alice"}];
    [_source clearState];
    XCTAssertNil([self contactData]);
}

- (void)testDeviceIdMissingNoOp {
    WPSyncContactSource *src = [[WPSyncContactSource alloc] initWithStateStore:_store
                                                          identifiersProvider:^NSDictionary *{ return @{@"userId": @"alice"}; }];
    [src applyData:@{@"firstName": @"Alice"}];
    XCTAssertNil([self contactData]);   // nothing persisted without a deviceId
}

#pragma mark - end to end through the orchestrator

- (void)testEndToEndResponseAppliesThenReadable {
    WPSync *sync = [[WPSync alloc] initWithStateStore:_store fetcher:[NoopFetching new]];
    sync.identifiersProvider = _ids;
    [sync registerSource:@"contact" plugin:_source];

    // Full reset via an opportunistic response.
    [sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_serverTime": @6000,
        @"_contactSync": @{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"data": @{@"firstName": @"Bob"}},
    }];
    XCTAssertEqualObjects([sync dataForSource:@"contact"], (@{@"firstName": @"Bob"}));
    XCTAssertEqual([_store loadSource:@"contact" userId:@"alice" deviceId:@"D1"].lastVersion, 200LL);

    // A later delta builds on it (explicit GET /contact response).
    [sync consumeIncomingResponseForPath:@"/contact" method:@"GET" response:@{
        @"version": @201, @"versionId": @"v201", @"readDate": @2001, @"delta": @{@"lastName": @"Jones"}, @"_serverTime": @6001,
    }];
    XCTAssertEqualObjects([sync dataForSource:@"contact"], (@{@"firstName": @"Bob", @"lastName": @"Jones"}));
}

@end
