//
//  WPSyncContactStoreTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncContactStore (issue wonderpush-ios-sdk-i2x.10). Ports all 6 cases of
// contact-store.vectors.json (replace / patch / null-removes / patch-onto-null / clear). Full
// JSON-driven run lands in the conformance harness (issue .11).

#import <XCTest/XCTest.h>
#import "WPSyncContactStore.h"

@interface WPSyncContactStoreTests : XCTestCase
@end

@implementation WPSyncContactStoreTests

- (void)testDataFullResetFromNull {
    NSDictionary *r = [WPSyncContactStore applyContactData:nil data:@{@"firstName": @"Alice", @"age": @30}];
    XCTAssertEqualObjects(r, (@{@"firstName": @"Alice", @"age": @30}));
}

- (void)testDataFullResetReplacesDroppingOldFields {
    NSDictionary *r = [WPSyncContactStore applyContactData:@{@"firstName": @"Alice", @"nickname": @"Al"}
                                                      data:@{@"firstName": @"Bob"}];
    XCTAssertEqualObjects(r, (@{@"firstName": @"Bob"}));
}

- (void)testDeltaPatchMerges {
    NSDictionary *r = [WPSyncContactStore applyContactDelta:@{@"firstName": @"Alice", @"age": @30}
                                                      delta:@{@"lastName": @"Smith", @"age": @31}];
    XCTAssertEqualObjects(r, (@{@"firstName": @"Alice", @"age": @31, @"lastName": @"Smith"}));
}

- (void)testDeltaNullRemovesField {
    NSDictionary *r = [WPSyncContactStore applyContactDelta:@{@"firstName": @"Alice", @"nickname": @"Al"}
                                                      delta:@{@"nickname": [NSNull null]}];
    XCTAssertEqualObjects(r, (@{@"firstName": @"Alice"}));
}

- (void)testDeltaOntoNullBase {
    NSDictionary *r = [WPSyncContactStore applyContactDelta:nil delta:@{@"firstName": @"Alice"}];
    XCTAssertEqualObjects(r, (@{@"firstName": @"Alice"}));
}

- (void)testClearReturnsNil {
    XCTAssertNil([WPSyncContactStore clearContact]);
}

- (void)testDataReplaceDoesNotAliasInput {
    NSMutableDictionary *input = [@{@"firstName": @"Alice"} mutableCopy];
    NSDictionary *r = [WPSyncContactStore applyContactData:nil data:input];
    input[@"firstName"] = @"Mutated";
    XCTAssertEqualObjects(r, (@{@"firstName": @"Alice"}));   // stored copy unaffected by later mutation
}

@end
