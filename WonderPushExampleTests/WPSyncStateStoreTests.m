//
//  WPSyncStateStoreTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncStateStore (issue wonderpush-ios-sdk-i2x.12): storage-key format, empty-state
// default, round-trip (incl. null fields), persistence across instances (app relaunch), and
// per-profile / per-source / per-device isolation + retention. Uses an isolated NSUserDefaults suite.

#import <XCTest/XCTest.h>
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"

static NSString * const kSuite = @"com.wonderpush.test.syncstatestore";

@interface WPSyncStateStoreTests : XCTestCase
@end

@implementation WPSyncStateStoreTests {
    NSUserDefaults *_defaults;
}

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
}

- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
}

- (WPSyncStateStore *)newStore {
    return [[WPSyncStateStore alloc] initWithUserDefaults:_defaults];
}

- (WPSyncSourceState *)populatedState {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastSyncDate = 5000;
    s.lastSyncMeta = @{@"syncVersion": @0, @"identifiers": @{@"contactId": @42}};
    s.lastVersion = 100;
    s.lastVersionId = @"v100";
    s.lastReadDate = 1000;
    s.data = @{@"firstName": @"Alice"};
    return s;
}

- (void)testStorageKeyFormat {
    XCTAssertEqualObjects([WPSyncStateStore storageKeyForSource:@"contact" userId:@"alice" deviceId:@"D1"], @"sync:contact:alice:D1");
    XCTAssertEqualObjects([WPSyncStateStore storageKeyForSource:@"contact" userId:nil deviceId:@"D1"], @"sync:contact::D1");
    XCTAssertEqualObjects([WPSyncStateStore storageKeyForSource:@"contact" userId:@"" deviceId:@"D1"], @"sync:contact::D1");
}

- (void)testLoadMissingReturnsEmptyState {
    WPSyncSourceState *s = [[self newStore] loadSource:@"contact" userId:@"alice" deviceId:@"D1"];
    XCTAssertEqualObjects(s, [WPSyncSourceState emptyState]);
}

- (void)testSaveLoadRoundTripWithNulls {
    WPSyncStateStore *store = [self newStore];
    WPSyncSourceState *s = [self populatedState];   // lastVersionId set, but exercise nulls too below
    [store saveState:s forSource:@"contact" userId:@"alice" deviceId:@"D1"];
    XCTAssertEqualObjects([store loadSource:@"contact" userId:@"alice" deviceId:@"D1"], s);

    // A state with null versionId / meta / data must round-trip too (JSON null <-> nil).
    WPSyncSourceState *empty = [WPSyncSourceState emptyState];
    empty.lastReadDate = 7;
    [store saveState:empty forSource:@"user" userId:@"alice" deviceId:@"D1"];
    WPSyncSourceState *back = [store loadSource:@"user" userId:@"alice" deviceId:@"D1"];
    XCTAssertEqualObjects(back, empty);
    XCTAssertNil(back.lastVersionId);
    XCTAssertNil(back.lastSyncMeta);
    XCTAssertNil(back.data);
}

- (void)testPersistsAcrossStoreInstances {
    [[self newStore] saveState:[self populatedState] forSource:@"contact" userId:@"alice" deviceId:@"D1"];
    // A fresh store on the same backing defaults == an app relaunch.
    WPSyncSourceState *s = [[self newStore] loadSource:@"contact" userId:@"alice" deviceId:@"D1"];
    XCTAssertEqualObjects(s, [self populatedState]);
}

- (void)testProfileIsolationAndRetention {
    WPSyncStateStore *store = [self newStore];
    WPSyncSourceState *alice = [self populatedState];
    WPSyncSourceState *anon = [WPSyncSourceState emptyState]; anon.lastVersion = 7;
    WPSyncSourceState *bob = [WPSyncSourceState emptyState]; bob.lastVersion = 9;

    [store saveState:alice forSource:@"contact" userId:@"alice" deviceId:@"D1"];
    [store saveState:anon forSource:@"contact" userId:nil deviceId:@"D1"];
    [store saveState:bob forSource:@"contact" userId:@"bob" deviceId:@"D1"];

    // Each profile keeps its own; switching back to alice still returns alice's (retention).
    XCTAssertEqual([store loadSource:@"contact" userId:@"alice" deviceId:@"D1"].lastVersion, 100LL);
    XCTAssertEqual([store loadSource:@"contact" userId:nil deviceId:@"D1"].lastVersion, 7LL);
    XCTAssertEqual([store loadSource:@"contact" userId:@"bob" deviceId:@"D1"].lastVersion, 9LL);
}

- (void)testSourceAndDeviceIsolation {
    WPSyncStateStore *store = [self newStore];
    WPSyncSourceState *c = [WPSyncSourceState emptyState]; c.lastVersion = 1;
    WPSyncSourceState *u = [WPSyncSourceState emptyState]; u.lastVersion = 2;
    [store saveState:c forSource:@"contact" userId:@"alice" deviceId:@"D1"];
    [store saveState:u forSource:@"user" userId:@"alice" deviceId:@"D1"];
    XCTAssertEqual([store loadSource:@"contact" userId:@"alice" deviceId:@"D1"].lastVersion, 1LL);
    XCTAssertEqual([store loadSource:@"user" userId:@"alice" deviceId:@"D1"].lastVersion, 2LL);
    // different device -> separate slot (empty)
    XCTAssertEqualObjects([store loadSource:@"contact" userId:@"alice" deviceId:@"D2"], [WPSyncSourceState emptyState]);
}

@end
