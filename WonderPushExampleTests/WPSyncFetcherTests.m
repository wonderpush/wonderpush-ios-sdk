//
//  WPSyncFetcherTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Unit tests for WPSyncFetcher (issue wonderpush-ios-sdk-i2x.16). A fake transport + an immediate
// scheduler (capturing the backoff delay) + fixed clock/random + a real WPSyncStateStore on an
// isolated suite make the loop fully synchronous and deterministic.

#import <XCTest/XCTest.h>
#import "WPSyncFetcher.h"
#import "WPSyncStateStore.h"
#import "WPSyncSourceState.h"
#import "WPSyncKnobs.h"
#import "WPSyncMutex.h"

static NSString * const kSuite = @"com.wonderpush.test.syncfetcher";
static const long long kNow = 1000000;

@interface FakeFetchTransport : NSObject <WPSyncFetchTransport>
@property (nonatomic) NSInteger callCount;
@property (nonatomic, copy, nullable) NSString *lastPath;
@property (nonatomic, copy, nullable) NSString *lastSource;
@property (nonatomic, copy, nullable) NSDictionary *lastParams;
@property (nonatomic) BOOL nextSuccess;
@end
@implementation FakeFetchTransport
- (void)fetchSource:(NSString *)source path:(NSString *)path params:(NSDictionary *)params
         completion:(void (^)(BOOL))completion {
    self.callCount++;
    self.lastSource = source; self.lastPath = path; self.lastParams = params;
    completion(self.nextSuccess);   // synchronous for deterministic tests
}
@end

@interface WPSyncFetcherTests : XCTestCase
@end

@implementation WPSyncFetcherTests {
    NSUserDefaults *_defaults;
    WPSyncStateStore *_store;
    FakeFetchTransport *_transport;
    WPSyncFetcher *_fetcher;
    WPSyncKnobs *_knobs;
    double _lastDelay;
}

- (void)setUp {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    _store = [[WPSyncStateStore alloc] initWithUserDefaults:_defaults];
    _transport = [FakeFetchTransport new];
    _transport.nextSuccess = YES;
    _fetcher = [[WPSyncFetcher alloc] initWithStateStore:_store transport:_transport];
    _lastDelay = -1;
    __weak typeof(self) ws = self;
    _fetcher.scheduler = ^(double delayMs, dispatch_block_t block) {
        typeof(self) s = ws; if (s) s->_lastDelay = delayMs;
        block();   // run immediately
    };
    _fetcher.nowProvider = ^long long{ return kNow; };
    _fetcher.randomProvider = ^double{ return 0.0; };   // no jitter
    _knobs = [WPSyncKnobs defaultKnobs];
}

- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:kSuite];
}

- (void)saveState:(WPSyncSourceState *)s forSource:(NSString *)source {
    [_store saveState:s forSource:source userId:@"alice" deviceId:@"D1"];
}
- (WPSyncSourceState *)loadSource:(NSString *)source {
    return [_store loadSource:source userId:@"alice" deviceId:@"D1"];
}
- (BOOL)fetch:(NSString *)source weak:(BOOL)weak {
    __block BOOL attempted = NO, called = NO;
    [_fetcher fetchSource:source userId:@"alice" deviceId:@"D1"
             identifiers:@{@"deviceId": @"D1", @"installationId": @"I1"}
                   knobs:_knobs weak:weak hint:nil
              completion:^(BOOL a) { attempted = a; called = YES; }];
    XCTAssertTrue(called, @"completion should run synchronously");
    return attempted;
}

#pragma mark - guards

- (void)testUnknownSourceAborts {
    XCTAssertFalse([self fetch:@"nope" weak:NO]);
    XCTAssertEqual(_transport.callCount, 0);
}

- (void)testWeakSignalDebouncedAborts {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastFetchAttemptedDate = kNow - 1000;   // within the 5000ms debounce window
    [self saveState:s forSource:@"contact"];
    XCTAssertFalse([self fetch:@"contact" weak:YES]);
    XCTAssertEqual(_transport.callCount, 0);
}

- (void)testRateLimitedAborts {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastFetchAttemptedDate = kNow - 500;    // within the 2000ms min-interval floor
    [self saveState:s forSource:@"user"];
    XCTAssertFalse([self fetch:@"user" weak:NO]);   // even a firm trigger is floored
    XCTAssertEqual(_transport.callCount, 0);
}

- (void)testMutexBusyAborts {
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"sync:popups"];
    NSUInteger t = [m tryLock];   // a fetch is "already in flight"
    XCTAssertFalse([self fetch:@"popups" weak:NO]);
    XCTAssertEqual(_transport.callCount, 0);
    [m unlock:t];
}

#pragma mark - the call

- (void)testAttemptStampsDateAndIssuesGetWithParams {
    XCTAssertTrue([self fetch:@"inbox" weak:NO]);
    XCTAssertEqual(_transport.callCount, 1);
    XCTAssertEqualObjects(_transport.lastSource, @"inbox");
    XCTAssertEqualObjects(_transport.lastPath, @"/inbox");
    XCTAssertEqualObjects(_transport.lastParams[@"deviceId"], @"D1");
    XCTAssertEqualObjects(_transport.lastParams[@"installationId"], @"I1");
    XCTAssertNil(_transport.lastParams[@"userId"]);            // userId added by the request layer, not here
    XCTAssertNotNil(_transport.lastParams[@"lastVersion"]);    // state trio present
    XCTAssertEqual([self loadSource:@"inbox"].lastFetchAttemptedDate, kNow);
}

- (void)testBackoffDelayZeroWithNoPriorFailures {
    XCTAssertTrue([self fetch:@"contact" weak:NO]);
    XCTAssertEqual(_lastDelay, 0.0);
}

- (void)testBackoffDelayFromFailureCount {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastFetchUnsuccessfulAttemptCount = 3;   // 1000 * 2^3 = 8000, rand 0 -> no jitter
    [self saveState:s forSource:@"contact"];
    XCTAssertTrue([self fetch:@"contact" weak:NO]);
    XCTAssertEqualWithAccuracy(_lastDelay, 8000.0, 1e-6);
}

#pragma mark - failure-count bookkeeping

- (void)testSuccessResetsFailureCount {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastFetchUnsuccessfulAttemptCount = 3;
    [self saveState:s forSource:@"user"];
    _transport.nextSuccess = YES;
    XCTAssertTrue([self fetch:@"user" weak:NO]);
    XCTAssertEqual([self loadSource:@"user"].lastFetchUnsuccessfulAttemptCount, 0);   // reset on success
}

- (void)testFailureLeavesIncrementedFailureCount {
    WPSyncSourceState *s = [WPSyncSourceState emptyState];
    s.lastFetchUnsuccessfulAttemptCount = 3;
    [self saveState:s forSource:@"installation"];
    _transport.nextSuccess = NO;
    XCTAssertTrue([self fetch:@"installation" weak:NO]);   // attempted, but the HTTP call failed
    XCTAssertEqual([self loadSource:@"installation"].lastFetchUnsuccessfulAttemptCount, 4);  // 3 -> 4, not reset
}

- (void)testMutexReleasedAfterFetch {
    XCTAssertTrue([self fetch:@"contact" weak:NO]);
    WPSyncMutex *m = [WPSyncMutex mutexNamed:@"sync:contact"];
    NSUInteger t = [m tryLock];
    XCTAssertNotEqual(t, 0u);   // released by the completion -> acquirable again
    [m unlock:t];
}

@end
