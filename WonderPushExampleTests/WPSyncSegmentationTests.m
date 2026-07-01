//
//  WPSyncSegmentationTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Tests for the `contact` segmentation namespace (issue wonderpush-ios-sdk-i2x.26): a segment that
// references contact.* must evaluate against the synced contact object, distinct from installation.

#import <XCTest/XCTest.h>
#import "WPSPSegmenter.h"

@interface WPSyncSegmentationTests : XCTestCase
@end

@implementation WPSyncSegmentationTests

- (BOOL)segment:(NSDictionary *)segment matchesInstallation:(NSDictionary *)installation contact:(NSDictionary *)contact {
    WPSPSegmenterData *data = [[WPSPSegmenterData alloc] initWithInstallation:installation allEvents:@[] presenceInfo:nil lastAppOpenDate:0];
    data.contact = contact;
    WPSPSegmenter *segmenter = [[WPSPSegmenter alloc] initWithData:data];
    return [segmenter parsedSegmentMatchesInstallation:[WPSPSegmenter parseInstallationSegment:segment]];
}

- (void)testMatchesContactField {
    NSDictionary *seg = @{@"contact": @{@".firstName": @{@"eq": @"Alice"}}};
    XCTAssertTrue([self segment:seg matchesInstallation:@{} contact:@{@"firstName": @"Alice"}]);
    XCTAssertFalse([self segment:seg matchesInstallation:@{} contact:@{@"firstName": @"Bob"}]);
    XCTAssertFalse([self segment:seg matchesInstallation:@{} contact:nil]);   // no synced contact -> non-match
}

- (void)testContactIsDistinctFromInstallation {
    // An installation custom field named firstName must NOT satisfy a contact criterion.
    NSDictionary *seg = @{@"contact": @{@".firstName": @{@"eq": @"Alice"}}};
    XCTAssertFalse([self segment:seg matchesInstallation:@{@"firstName": @"Alice"} contact:nil]);
}

- (void)testNestedContactAttribute {
    NSDictionary *seg = @{@"contact": @{@".attributes.PLAN": @{@"eq": @"pro"}}};
    XCTAssertTrue([self segment:seg matchesInstallation:@{} contact:@{@"attributes": @{@"PLAN": @"pro"}}]);
    XCTAssertFalse([self segment:seg matchesInstallation:@{} contact:@{@"attributes": @{@"PLAN": @"free"}}]);
}

- (void)testInstallationSegmentStillWorksAlongsideContact {
    // Sanity: the existing installation namespace is unaffected by adding contact.
    NSDictionary *seg = @{@".custom.tier": @{@"eq": @"gold"}};
    XCTAssertTrue([self segment:seg matchesInstallation:@{@"custom": @{@"tier": @"gold"}} contact:nil]);
}

@end
