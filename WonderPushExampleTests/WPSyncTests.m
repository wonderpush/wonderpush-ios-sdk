//
//  WPSyncTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for the WPSync orchestrator (issue wonderpush-ios-sdk-i2x.18): registration, outgoing
// param injection, incoming response consumption (apply/save/trigger per source), max-age forcing,
// and the deviceId invariant. A fake plugin + fake fetcher + a real WPSyncStateStore on an isolated
// suite keep it deterministic.

#import <XCTest/XCTest.h>
#import "WPSync.h"
#import "WPSyncFetcher.h"     // WPSyncFetching
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"
#import "WPSyncKnobs.h"
#import "WPSyncDecision.h"    // WPSyncFetchHint

static NSString * const kSuite = @"com.wonderpush.test.wpsync";
static const long long kNow = 1000000;

@interface FakePlugin : NSObject <WPSyncSourcePlugin>
@property (nonatomic) NSInteger clearCount;
@property (nonatomic) BOOL applyDataCalled;
@property (nonatomic, strong, nullable) id lastData;
@property (nonatomic) BOOL applyDeltaCalled;
@property (nonatomic, strong, nullable) id lastDelta;
@end
@implementation FakePlugin
- (void)clearState { self.clearCount++; }
- (void)applyData:(id)data { self.applyDataCalled = YES; self.lastData = data; }
- (void)applyDelta:(id)delta { self.applyDeltaCalled = YES; self.lastDelta = delta; }
@end

@interface FakeFetching : NSObject <WPSyncFetching>
@property (nonatomic) NSInteger callCount;
@property (nonatomic, copy, nullable) NSString *lastSource;
@property (nonatomic) BOOL lastWeak;
@property (nonatomic, strong, nullable) WPSyncFetchHint *lastHint;
@end
@implementation FakeFetching
- (void)fetchSource:(NSString *)source userId:(NSString *)userId deviceId:(NSString *)deviceId
        identifiers:(NSDictionary *)identifiers knobs:(WPSyncKnobs *)knobs weak:(BOOL)weak
               hint:(WPSyncFetchHint *)hint completion:(void (^)(BOOL))completion {
    self.callCount++; self.lastSource = source; self.lastWeak = weak; self.lastHint = hint;
}
@end

@interface WPSyncTests : XCTestCase
@end

@implementation WPSyncTests {
    NSUserDefaults *_defaults;
    WPSyncStateStore *_store;
    FakeFetching *_fetcher;
    WPSync *_sync;
    WPSyncKnobs *_knobs;
}

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    _store = [[WPSyncStateStore alloc] initWithUserDefaults:_defaults];
    _fetcher = [FakeFetching new];
    _knobs = [WPSyncKnobs defaultKnobs];
    _sync = [[WPSync alloc] initWithStateStore:_store fetcher:_fetcher];
    __weak typeof(self) ws = self;
    _sync.identifiersProvider = ^NSDictionary *{ return @{@"userId": @"alice", @"deviceId": @"D1", @"installationId": @"I1"}; };
    _sync.knobsProvider = ^WPSyncKnobs *{ typeof(self) s = ws; return s->_knobs; };
    _sync.nowProvider = ^long long{ return kNow; };
}

- (void)tearDown { [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite]; }

- (WPSyncSourceState *)state:(NSString *)source { return [_store loadSource:source userId:@"alice" deviceId:@"D1"]; }
- (void)save:(WPSyncSourceState *)s source:(NSString *)source { [_store saveState:s forSource:source userId:@"alice" deviceId:@"D1"]; }

#pragma mark - registry

- (void)testRegisterAndList {
    [_sync registerSource:@"contact" plugin:nil];
    [_sync registerSource:@"user" plugin:[FakePlugin new]];
    NSArray *names = [_sync registeredSources];
    XCTAssertEqual(names.count, (NSUInteger)2);
    XCTAssertTrue([names containsObject:@"contact"]);
    XCTAssertTrue([names containsObject:@"user"]);
}

#pragma mark - outgoing

- (void)testPrepareOutgoingInjectsIdentifiersAndState {
    WPSyncSourceState *s = [WPSyncSourceState emptyState]; s.lastVersion = 5;
    [self save:s source:@"contact"];
    [_sync registerSource:@"contact" plugin:nil];
    NSDictionary *p = [_sync prepareOutgoingParamsForPath:@"/events" method:@"POST"];
    XCTAssertEqualObjects(p[@"_syncUserId"], @"alice");
    XCTAssertEqualObjects(p[@"_syncDeviceId"], @"D1");
    XCTAssertEqualObjects(p[@"_contactSync.lastVersion"], @5);
}

- (void)testPrepareOutgoingSkipsNonOpportunisticAndKillSwitch {
    [_sync registerSource:@"contact" plugin:nil];
    XCTAssertEqualObjects([_sync prepareOutgoingParamsForPath:@"/installation" method:@"GET"], @{});   // explicit fetch, not opp
    XCTAssertEqualObjects([_sync prepareOutgoingParamsForPath:@"/configuration" method:@"GET"], @{});
    _knobs.opportunisticInjectionEnabled = NO;
    XCTAssertEqualObjects([_sync prepareOutgoingParamsForPath:@"/events" method:@"POST"], @{});         // kill switch
}

#pragma mark - incoming: apply + save

- (void)testConsumeOpportunisticAppliesDataAndSavesState {
    FakePlugin *plugin = [FakePlugin new];
    [_sync registerSource:@"contact" plugin:plugin];
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_serverTime": @6000,
        @"_contactSync": @{@"version": @200, @"versionId": @"v200", @"readDate": @2000, @"data": @{@"firstName": @"Bob"}},
    }];
    XCTAssertTrue(plugin.applyDataCalled);
    XCTAssertEqualObjects(plugin.lastData, (@{@"firstName": @"Bob"}));
    WPSyncSourceState *s = [self state:@"contact"];
    XCTAssertEqual(s.lastVersion, 200LL);
    XCTAssertEqual(s.lastSyncDate, 6000LL);
}

- (void)testConsumeExplicitProjectsTopLevelBlock {
    FakePlugin *plugin = [FakePlugin new];
    [_sync registerSource:@"contact" plugin:plugin];
    [_sync consumeIncomingResponseForPath:@"/contact" method:@"GET" response:@{
        @"version": @100, @"versionId": @"v100", @"readDate": @1000, @"data": @{@"x": @1}, @"_serverTime": @5000,
    }];
    XCTAssertTrue(plugin.applyDataCalled);
    XCTAssertEqualObjects(plugin.lastData, (@{@"x": @1}));
    XCTAssertEqual([self state:@"contact"].lastVersion, 100LL);
}

- (void)testConsumeIgnoresNonSyncResponse {
    FakePlugin *plugin = [FakePlugin new];
    [_sync registerSource:@"contact" plugin:plugin];
    [_sync consumeIncomingResponseForPath:@"/configuration" method:@"GET" response:@{@"foo": @1}];
    XCTAssertFalse(plugin.applyDataCalled);
    XCTAssertEqual(_fetcher.callCount, 0);
}

#pragma mark - incoming: fetch triggers

- (void)testFirmHeadHintTriggersFirmFetch {
    WPSyncSourceState *s = [WPSyncSourceState emptyState]; s.lastVersion = 100; s.lastVersionId = @"v100"; s.lastReadDate = 1000;
    [self save:s source:@"contact"];
    [_sync registerSource:@"contact" plugin:nil];
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{
        @"_contactSync": @{@"knownVersion": @200, @"knownVersionId": @"v200", @"knownReadDate": @2000},
    }];
    XCTAssertEqual(_fetcher.callCount, 1);
    XCTAssertEqualObjects(_fetcher.lastSource, @"contact");
    XCTAssertFalse(_fetcher.lastWeak);                       // firm
    XCTAssertEqualObjects(_fetcher.lastHint.knownVersion, @200);
}

- (void)testEmptyBlockTriggersWeakFetch {
    [_sync registerSource:@"contact" plugin:nil];
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{@"_contactSync": @{}}];
    XCTAssertEqual(_fetcher.callCount, 1);
    XCTAssertTrue(_fetcher.lastWeak);                        // "try asking explicitly" -> weak
}

#pragma mark - max-age forcing

- (void)testMaxAgeForcingTriggersFirmFetchForStaleSource {
    _knobs.maxLastReadDateAgeMs = 5000;                      // finite cap enables forcing
    WPSyncSourceState *s = [WPSyncSourceState emptyState]; s.lastReadDate = kNow - 10000;   // stale
    [self save:s source:@"contact"];
    [_sync registerSource:@"contact" plugin:nil];
    // A response with no contact block: nothing applied, but max-age forcing should fire.
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{@"_serverTime": @(kNow)}];
    XCTAssertEqual(_fetcher.callCount, 1);
    XCTAssertEqualObjects(_fetcher.lastSource, @"contact");
    XCTAssertFalse(_fetcher.lastWeak);                       // firm
}

- (void)testNoMaxAgeForcingWhenCapsInfinite {
    WPSyncSourceState *s = [WPSyncSourceState emptyState]; s.lastReadDate = 1;   // ancient, but caps are +Inf by default
    [self save:s source:@"contact"];
    [_sync registerSource:@"contact" plugin:nil];
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{@"_serverTime": @(kNow)}];
    XCTAssertEqual(_fetcher.callCount, 0);
}

#pragma mark - deviceId invariant + read

- (void)testNoOpWhenDeviceIdMissing {
    _sync.identifiersProvider = ^NSDictionary *{ return @{@"userId": @"alice"}; };   // no deviceId
    FakePlugin *plugin = [FakePlugin new];
    [_sync registerSource:@"contact" plugin:plugin];
    XCTAssertEqualObjects([_sync prepareOutgoingParamsForPath:@"/events" method:@"POST"], @{});
    [_sync consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{@"_contactSync": @{@"version": @1, @"data": @{}}}];
    XCTAssertFalse(plugin.applyDataCalled);
    XCTAssertEqual(_fetcher.callCount, 0);
}

- (void)testDataForSource {
    WPSyncSourceState *s = [WPSyncSourceState emptyState]; s.data = @{@"firstName": @"Alice"};
    [self save:s source:@"contact"];
    XCTAssertEqualObjects([_sync dataForSource:@"contact"], (@{@"firstName": @"Alice"}));
    XCTAssertNil([_sync dataForSource:@"user"]);
}

@end
