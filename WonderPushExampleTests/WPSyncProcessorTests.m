//
//  WPSyncProcessorTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncProcessor (issue wonderpush-ios-sdk-i2x.9). Ports every case from
// classify-response.vectors.json (7) and process-source-block.vectors.json (15): builds the block
// and state from the vector dicts and deep-compares [decision toDictionary] to the expected output.
// The full JSON-driven run lands in the conformance harness (issue .11).

#import <XCTest/XCTest.h>
#import "WPSyncProcessor.h"
#import "WPSyncResponseBlock.h"
#import "WPSyncSourceState.h"
#import "WPSyncDecision.h"

/// base + overrides (shallow), so we can express "the baseline state with a few fields changed".
static NSDictionary *M(NSDictionary *base, NSDictionary *overrides) {
    NSMutableDictionary *d = [base mutableCopy];
    [d addEntriesFromDictionary:overrides];
    return d;
}

@interface WPSyncProcessorTests : XCTestCase
@end

@implementation WPSyncProcessorTests {
    NSDictionary *_base;   // the baseline state shared by most process-source-block vectors
}

- (void)setUp {
    _base = @{
        @"lastSyncDate": @5000, @"lastSyncMeta": @{@"m": @1},
        @"lastVersion": @100, @"lastVersionId": @"v100", @"lastReadDate": @1000,
        @"lastFetchAttemptedDate": @0, @"lastFetchUnsuccessfulAttemptCount": @0,
        @"data": @{@"firstName": @"Alice"},
    };
}

#pragma mark - classifyResponse

- (void)assertClassifyPath:(id)path method:(id)method expects:(NSDictionary *)expected {
    WPSyncResponseClassification *c =
        [WPSyncProcessor classifyResponsePath:(path == [NSNull null] ? nil : path)
                                       method:(method == [NSNull null] ? nil : method)];
    XCTAssertEqualObjects([c toDictionary], expected);
}

- (void)testClassifyResponse {
    [self assertClassifyPath:@"/events" method:@"POST" expects:@{@"mode": @"opportunistic"}];
    [self assertClassifyPath:@"/v1/events" method:@"POST" expects:@{@"mode": @"opportunistic"}];
    [self assertClassifyPath:@"/installation" method:@"PATCH" expects:@{@"mode": @"opportunistic"}];
    [self assertClassifyPath:@"/contact" method:@"GET" expects:@{@"mode": @"explicit", @"explicitSource": @"contact"}];
    [self assertClassifyPath:@"/v1/popups" method:@"GET" expects:@{@"mode": @"explicit", @"explicitSource": @"popups"}];
    [self assertClassifyPath:@"/configuration" method:@"GET" expects:@{@"mode": @"none"}];
    [self assertClassifyPath:[NSNull null] method:[NSNull null] expects:@{@"mode": @"none"}];
}

#pragma mark - processSourceBlock

- (void)runBlock:(id)blockVal serverTime:(id)st mode:(NSString *)mode
           state:(NSDictionary *)stateDict expects:(NSDictionary *)expected name:(NSString *)name {
    WPSyncResponseBlock *block = (blockVal == [NSNull null]) ? nil : [WPSyncResponseBlock blockWithDictionary:blockVal];
    NSNumber *serverTime = (st == [NSNull null]) ? nil : st;
    WPSyncSourceState *state = [WPSyncSourceState stateWithDictionary:stateDict];
    WPSyncDecision *d = [WPSyncProcessor processSourceBlock:block serverTime:serverTime state:state mode:mode];
    XCTAssertEqualObjects([d toDictionary], expected, @"%@", name);
}

- (void)testBlockMissing {
    [self runBlock:[NSNull null] serverTime:[NSNull null] mode:@"opportunistic" state:_base expects:@{} name:@"block missing"];
}

- (void)testEmptyBlock {
    [self runBlock:@{} serverTime:@500 mode:@"opportunistic" state:_base expects:@{@"triggerFetch": @"weak"} name:@"empty opportunistic"];
    [self runBlock:@{} serverTime:@500 mode:@"explicit" state:_base expects:@{} name:@"empty explicit"];
}

- (void)testMetaOnlyEcho {
    [self runBlock:@{@"meta": @{@"x": @2}} serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"newState": M(_base, @{@"lastSyncMeta": @{@"x": @2}})} name:@"meta-only echo"];
}

- (void)testDataAcceptedReplace {
    [self runBlock:@{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"data": @{@"firstName": @"Bob"}}
        serverTime:@6000 mode:@"opportunistic" state:_base
           expects:@{@"applyData": @{@"firstName": @"Bob"},
                     @"newState": M(_base, @{@"lastSyncDate": @6000, @"lastVersion": @200, @"lastVersionId": @"v200", @"lastReadDate": @2000})}
              name:@"data accepted (replace)"];
}

- (void)testDeltaAcceptedPatch {
    [self runBlock:@{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"delta": @{@"lastName": @"Smith"}}
        serverTime:@6000 mode:@"opportunistic" state:_base
           expects:@{@"applyDelta": @{@"lastName": @"Smith"},
                     @"newState": M(_base, @{@"lastSyncDate": @6000, @"lastVersion": @200, @"lastVersionId": @"v200", @"lastReadDate": @2000})}
              name:@"delta accepted (patch)"];
}

- (void)testStalePayloadRejected {
    [self runBlock:@{@"version": @50, @"versionId": @"v50", @"readDate": @10, @"data": @{@"x": @1}}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base expects:@{} name:@"stale payload rejected"];
}

- (void)testEmptyResetWipes {
    [self runBlock:@{@"version": @0, @"versionId": [NSNull null], @"readDate": @3000, @"data": @{}}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"clearState": @YES, @"applyData": @{},
                     @"newState": M(_base, @{@"lastVersion": @0, @"lastVersionId": [NSNull null], @"lastReadDate": @3000})}
              name:@"empty-reset wipes"];
}

- (void)testNoChangeConfirmedAdvancesReadDate {
    [self runBlock:@{@"version": @100, @"versionId": @"v100", @"readDate": @2000}
        serverTime:@6000 mode:@"explicit" state:_base
           expects:@{@"newState": M(_base, @{@"lastSyncDate": @6000, @"lastReadDate": @2000})}
              name:@"no-change-confirmed advances readDate"];
}

- (void)testNoPayloadStrictlyHigherFirmFetch {
    [self runBlock:@{@"version": @300, @"versionId": @"v300"}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"triggerFetch": @"firm"} name:@"no-payload strictly-higher"];
}

- (void)testDegenerateReadDateOnly {
    [self runBlock:@{@"readDate": @2000}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"newState": M(_base, @{@"lastReadDate": @2000})} name:@"degenerate readDate-only"];
}

- (void)testFirmHeadHint {
    [self runBlock:@{@"knownVersion": @200, @"knownVersionId": @"v200", @"knownReadDate": @2000}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"triggerFetch": @"firm",
                     @"fetchHint": @{@"knownVersion": @200, @"knownVersionId": @"v200", @"knownReadDate": @2000}}
              name:@"firm head hint"];
}

- (void)testHeadHintEqualNoFetch {
    [self runBlock:@{@"knownVersion": @100, @"knownVersionId": @"v100", @"knownReadDate": @2000}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base expects:@{} name:@"head hint equal -> no fetch"];
}

- (void)testWeakHeadHintReadDateOnly {
    [self runBlock:@{@"knownReadDate": @2000}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"triggerFetch": @"weak", @"fetchHint": @{@"knownReadDate": @2000}}
              name:@"weak head hint"];
}

- (void)testHeadHintVsJustUpdatedVersionNoFetch {
    [self runBlock:@{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"data": @{@"x": @1},
                     @"knownVersion": @200, @"knownVersionId": @"v200", @"knownReadDate": @2000}
        serverTime:[NSNull null] mode:@"opportunistic" state:_base
           expects:@{@"applyData": @{@"x": @1},
                     @"newState": M(_base, @{@"lastVersion": @200, @"lastVersionId": @"v200", @"lastReadDate": @2000})}
              name:@"head hint vs just-updated version"];
}

@end
