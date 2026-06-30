//
//  WPSyncContactSourceTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Tests for WPSyncContactSource (issue wonderpush-ios-sdk-i2x.19): the stateless transformer's
// reset/delta semantics, and an end-to-end path through the WPSync orchestrator (response ->
// orchestrator applies the transform under the captured profile -> dataForSource).

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
}

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    _store = [[WPSyncStateStore alloc] initWithUserDefaults:_defaults];
    _source = [WPSyncContactSource new];
}

- (void)tearDown { [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite]; }

#pragma mark - the stateless transforms

- (void)testApplyDataReplaces {
    XCTAssertEqualObjects([_source dataByApplyingData:(@{@"firstName": @"Alice", @"age": @30}) toCurrentData:nil],
                          (@{@"firstName": @"Alice", @"age": @30}));
    // full reset drops old fields
    XCTAssertEqualObjects([_source dataByApplyingData:@{@"firstName": @"Bob"} toCurrentData:(@{@"firstName": @"Alice", @"nickname": @"Al"})],
                          (@{@"firstName": @"Bob"}));
}

- (void)testApplyDeltaMerges {
    XCTAssertEqualObjects([_source dataByApplyingDelta:@{@"lastName": @"Smith"} toCurrentData:@{@"firstName": @"Alice"}],
                          (@{@"firstName": @"Alice", @"lastName": @"Smith"}));
}

- (void)testApplyDeltaNullRemovesField {
    XCTAssertEqualObjects([_source dataByApplyingDelta:@{@"nickname": [NSNull null]} toCurrentData:(@{@"firstName": @"Alice", @"nickname": @"Al"})],
                          (@{@"firstName": @"Alice"}));
}

#pragma mark - end to end through the orchestrator

- (void)testEndToEndResetDeltaAndClear {
    WPSync *sync = [[WPSync alloc] initWithStateStore:_store fetcher:[NoopFetching new]];
    sync.identifiersProvider = ^NSDictionary *{ return @{@"userId": @"alice", @"deviceId": @"D1"}; };
    [sync registerSource:@"contact" plugin:_source];

    // Full reset via opportunistic response.
    [sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_serverTime": @6000,
        @"_contactSync": @{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"data": @{@"firstName": @"Bob"}},
    }];
    XCTAssertEqualObjects([sync dataForSource:@"contact"], (@{@"firstName": @"Bob"}));

    // Delta builds on it (explicit GET /contact).
    [sync consumeIncomingResponseForPath:@"/contact" method:@"GET" response:@{
        @"version": @201, @"versionId": @"v201", @"readDate": @2001, @"delta": @{@"lastName": @"Jones"}, @"_serverTime": @6001,
    }];
    XCTAssertEqualObjects([sync dataForSource:@"contact"], (@{@"firstName": @"Bob", @"lastName": @"Jones"}));

    // Empty-reset wipes to {} (version 0 + empty data + newer readDate).
    [sync consumeIncomingResponseForPath:@"/contact" method:@"GET" response:@{
        @"version": @0, @"versionId": [NSNull null], @"readDate": @3000, @"data": @{}, @"_serverTime": @6002,
    }];
    XCTAssertEqualObjects([sync dataForSource:@"contact"], @{});
    XCTAssertEqual([_store loadSource:@"contact" userId:@"alice" deviceId:@"D1"].lastVersion, 0LL);
}

@end
