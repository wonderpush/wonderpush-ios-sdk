//
//  WPSyncPopupsMergeTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Tests the merge of synced popups into the in-app engine (issue .27):
// WPIAMMessageClientCache.messagesByMergingRemoteMessages:withSyncedPopups:now:. Mirrors the JS merge
// in inappmessaging/main.ts:284-298 — remote-config campaigns first, then synced popups (no dedupe),
// tombstones (status==deleted) and expired items excluded. Real campaign payloads are taken from the
// bundled remote-config-example.json and re-stamped with known campaignIds so ordering/exclusion is
// assertable.

#import <XCTest/XCTest.h>
#import "WPIAMMessageClientCache.h"
#import "WPIAMFetchResponseParser.h"
#import "WPIAMMessageDefinition.h"

static const long long NOW = 2000000000000;   // ms; comfortably in the future vs. example startDate

@interface WPSyncPopupsMergeTests : XCTestCase
@end

@implementation WPSyncPopupsMergeTests

// A real, parseable campaign dict from the bundled example, deep-copied and re-stamped with `cid` as
// its notification's reporting.campaignId (so parsed WPIAMMessageDefinitions are distinguishable).
- (NSDictionary *)campaignWithId:(NSString *)cid {
    NSURL *url = [[NSBundle bundleForClass:self.class] URLForResource:@"remote-config-example" withExtension:@"json"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *template = root[@"inAppConfig"][@"campaigns"][0];
    NSMutableDictionary *campaign = [NSJSONSerialization JSONObjectWithData:
        [NSJSONSerialization dataWithJSONObject:template options:0 error:nil]
        options:NSJSONReadingMutableContainers error:nil];
    campaign[@"notifications"][0][@"reporting"][@"campaignId"] = cid;
    return campaign;
}

- (WPIAMMessageDefinition *)remoteMessageWithId:(NSString *)cid {
    NSInteger discard;
    NSArray *parsed = [WPIAMFetchResponseParser parseAPIResponseDictionary:@{@"campaigns": @[[self campaignWithId:cid]]}
                                                         discardedMsgCount:&discard];
    XCTAssertEqual(parsed.count, 1u, @"template campaign should parse");
    return parsed[0];
}

// A synced popup item: {id, status, expirationDate, data:<campaign with campaignId>}.
- (NSDictionary *)popupWithCampaignId:(NSString *)cid status:(NSString *)status expiration:(long long)exp {
    NSMutableDictionary *p = [@{@"id": cid, @"data": [self campaignWithId:cid]} mutableCopy];
    if (status) p[@"status"] = status;
    if (exp) p[@"expirationDate"] = @(exp);
    return p;
}

- (NSArray<NSString *> *)campaignIdsOf:(NSArray<WPIAMMessageDefinition *> *)messages {
    NSMutableArray *out = [NSMutableArray array];
    for (WPIAMMessageDefinition *m in messages) [out addObject:m.renderData.reportingData.campaignId ?: @"<nil>"];
    return out;
}

- (void)testRemoteFirstThenSynced {
    NSArray *remote = @[[self remoteMessageWithId:@"remote-1"], [self remoteMessageWithId:@"remote-2"]];
    NSArray *popups = @[[self popupWithCampaignId:@"synced-1" status:@"active" expiration:NOW + 100000],
                        [self popupWithCampaignId:@"synced-2" status:nil expiration:0]];
    NSArray *merged = [WPIAMMessageClientCache messagesByMergingRemoteMessages:remote withSyncedPopups:popups now:NOW];
    XCTAssertEqualObjects([self campaignIdsOf:merged], (@[@"remote-1", @"remote-2", @"synced-1", @"synced-2"]));
}

- (void)testTombstonesExcluded {
    NSArray *popups = @[[self popupWithCampaignId:@"keep" status:@"active" expiration:0],
                        [self popupWithCampaignId:@"gone" status:@"deleted" expiration:NOW + 100000]];
    NSArray *merged = [WPIAMMessageClientCache messagesByMergingRemoteMessages:@[] withSyncedPopups:popups now:NOW];
    XCTAssertEqualObjects([self campaignIdsOf:merged], (@[@"keep"]));
}

- (void)testExpiredExcluded {
    NSArray *popups = @[[self popupWithCampaignId:@"fresh" status:@"active" expiration:NOW + 100000],
                        [self popupWithCampaignId:@"stale" status:@"active" expiration:NOW - 1]];
    NSArray *merged = [WPIAMMessageClientCache messagesByMergingRemoteMessages:@[] withSyncedPopups:popups now:NOW];
    XCTAssertEqualObjects([self campaignIdsOf:merged], (@[@"fresh"]));
}

- (void)testMalformedOrMissingDataSkipped {
    NSArray *popups = @[@"not-a-dict",
                        @{@"id": @"no-data"},                                  // missing data
                        @{@"id": @"bad-data", @"data": @"nope"},               // data not a dict
                        @{@"id": @"unparseable", @"data": @{@"foo": @"bar"}},  // dict but not a valid campaign
                        [self popupWithCampaignId:@"good" status:@"active" expiration:0]];
    NSArray *merged = [WPIAMMessageClientCache messagesByMergingRemoteMessages:@[] withSyncedPopups:popups now:NOW];
    XCTAssertEqualObjects([self campaignIdsOf:merged], (@[@"good"]));
}

- (void)testNilOrEmptySyncedReturnsRemoteUnchanged {
    NSArray *remote = @[[self remoteMessageWithId:@"r"]];
    XCTAssertEqualObjects([self campaignIdsOf:[WPIAMMessageClientCache messagesByMergingRemoteMessages:remote withSyncedPopups:nil now:NOW]], (@[@"r"]));
    XCTAssertEqualObjects([self campaignIdsOf:[WPIAMMessageClientCache messagesByMergingRemoteMessages:remote withSyncedPopups:@[] now:NOW]], (@[@"r"]));
}

- (void)testNilRemoteTolerated {
    NSArray *popups = @[[self popupWithCampaignId:@"only-synced" status:@"active" expiration:0]];
    NSArray *merged = [WPIAMMessageClientCache messagesByMergingRemoteMessages:nil withSyncedPopups:popups now:NOW];
    XCTAssertEqualObjects([self campaignIdsOf:merged], (@[@"only-synced"]));
}

@end
