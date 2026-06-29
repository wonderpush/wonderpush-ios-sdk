//
//  WPSyncVersionIdTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncVersionId (issue wonderpush-ios-sdk-i2x.6): the versionId total order and
// the acceptance check. Representative cases drawn from compare-version-id.vectors.json (81 cases)
// and accepts-response.vectors.json (9 cases); the full vector-driven run lands in the conformance
// harness (issue .11).

#import <XCTest/XCTest.h>
#import "WPSyncVersionId.h"

@interface WPSyncVersionIdTests : XCTestCase
@end

@implementation WPSyncVersionIdTests

#pragma mark - compareVersionId

- (NSComparisonResult)cmp:(id)a :(id)b { return [WPSyncVersionId compareVersionId:a with:b]; }

- (void)testNullMissingEquality {
    XCTAssertEqual([self cmp:nil :nil], NSOrderedSame);
    XCTAssertEqual([self cmp:[NSNull null] :nil], NSOrderedSame);          // NSNull == nil sentinel
    XCTAssertEqual([self cmp:[NSNull null] :[NSNull null]], NSOrderedSame);
}

- (void)testNullIsLessThanAnything {
    XCTAssertEqual([self cmp:nil :@0], NSOrderedAscending);
    XCTAssertEqual([self cmp:nil :@100], NSOrderedAscending);
    XCTAssertEqual([self cmp:nil :@"a"], NSOrderedAscending);
    XCTAssertEqual([self cmp:@0 :nil], NSOrderedDescending);
    XCTAssertEqual([self cmp:@"a" :[NSNull null]], NSOrderedDescending);
}

- (void)testNumberIsLessThanString {
    XCTAssertEqual([self cmp:@100 :@"a"], NSOrderedAscending);
    XCTAssertEqual([self cmp:@"a" :@100], NSOrderedDescending);
    XCTAssertEqual([self cmp:@999999999999 :@"0"], NSOrderedAscending);
}

- (void)testNumericNaturalOrder {
    XCTAssertEqual([self cmp:@1 :@2], NSOrderedAscending);
    XCTAssertEqual([self cmp:@2 :@1], NSOrderedDescending);
    XCTAssertEqual([self cmp:@100 :@100], NSOrderedSame);
    XCTAssertEqual([self cmp:@9223372036854775807 :@1], NSOrderedDescending); // int64 max
}

- (void)testStringByteWiseOrder {
    XCTAssertEqual([self cmp:@"a" :@"b"], NSOrderedAscending);
    XCTAssertEqual([self cmp:@"b" :@"a"], NSOrderedDescending);
    XCTAssertEqual([self cmp:@"v100" :@"v100"], NSOrderedSame);
    XCTAssertEqual([self cmp:@"v100" :@"v2"], NSOrderedAscending);   // '1'(0x31) < '2'(0x32)
    XCTAssertEqual([self cmp:@"Z" :@"a"], NSOrderedAscending);       // case-sensitive: 'Z'(0x5A) < 'a'(0x61)
}

- (void)testStringEmbeddedNulNotTruncated {
    // Strings sharing a prefix up to an embedded NUL must still compare by what follows it.
    NSString *ab = [[NSString alloc] initWithBytes:"a\0b" length:3 encoding:NSUTF8StringEncoding];
    NSString *ac = [[NSString alloc] initWithBytes:"a\0c" length:3 encoding:NSUTF8StringEncoding];
    XCTAssertEqual([self cmp:ab :ac], NSOrderedAscending);   // 'b' < 'c' after the NUL (would be Same with strcmp)
    XCTAssertEqual([self cmp:ab :ab], NSOrderedSame);
}

- (void)testStringNonAsciiCodeUnitOrder {
    // Code-unit ordering (matches the JS reference): 'a'(0x61) < 'é'(0xE9).
    XCTAssertEqual([self cmp:@"a" :@"é"], NSOrderedAscending);
    XCTAssertEqual([self cmp:@"é" :@"a"], NSOrderedDescending);
}

#pragma mark - acceptsResponse

- (BOOL)accept:(long long)v vid:(id)vid rd:(long long)rd data:(id)data
          lastV:(long long)lv lastVid:(id)lvid lastRd:(long long)lrd {
    return [WPSyncVersionId acceptsResponseWithVersion:v versionId:vid readDate:rd data:data
                                          lastVersion:lv lastVersionId:lvid lastReadDate:lrd];
}

- (void)testMonotonicAcceptance {
    // higher version
    XCTAssertTrue([self accept:101 vid:@"v100" rd:1000 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
    // same version, higher versionId
    XCTAssertTrue([self accept:100 vid:@"v200" rd:1000 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
    // same version+id, higher readDate
    XCTAssertTrue([self accept:100 vid:@"v100" rd:1001 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
    // from empty state, any positive version
    XCTAssertTrue([self accept:1 vid:nil rd:1 data:@{} lastV:0 lastVid:nil lastRd:0]);
}

- (void)testRejection {
    // identical tuple
    XCTAssertFalse([self accept:100 vid:@"v100" rd:1000 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
    // lower version (even with much newer readDate)
    XCTAssertFalse([self accept:99 vid:@"v100" rd:9999 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
}

- (void)testEmptyReset {
    // v0 + {} + newer readDate
    XCTAssertTrue([self accept:0 vid:nil rd:1001 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
    // v0 + [] + newer readDate
    XCTAssertTrue([self accept:0 vid:nil rd:2000 data:@[] lastV:100 lastVid:@"v100" lastRd:1000]);
    // v0 but stale readDate -> not accepted
    XCTAssertFalse([self accept:0 vid:nil rd:1000 data:@{} lastV:100 lastVid:@"v100" lastRd:1000]);
    // v0 but non-empty data -> not an empty-reset (and version not higher) -> not accepted
    XCTAssertFalse([self accept:0 vid:nil rd:5000 data:@{@"x": @1} lastV:100 lastVid:@"v100" lastRd:1000]);
    // NSNull data is not an empty payload
    XCTAssertFalse([self accept:0 vid:nil rd:5000 data:[NSNull null] lastV:100 lastVid:@"v100" lastRd:1000]);
}

@end
