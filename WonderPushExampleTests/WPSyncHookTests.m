//
//  WPSyncHookTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// Tests for the WPSyncHook observer seam (issues .14/.15): install/replace/clear, and that WPSync
// satisfies WPSyncRequestObserver so it can be installed as the request observer.

#import <XCTest/XCTest.h>
#import "WPSyncRequestObserver.h"
#import "WPSync.h"
#import "WPSyncFetcher.h"
#import "WPSyncStateStore.h"
#import "WPSyncKnobs.h"
#import "WPSyncDecision.h"

@interface RecordingObserver : NSObject <WPSyncRequestObserver>
@property (nonatomic, copy, nullable) NSString *lastPath;
@property (nonatomic) BOOL consumed;
@end
@implementation RecordingObserver
- (NSDictionary *)prepareOutgoingParamsForPath:(NSString *)path method:(NSString *)method {
    self.lastPath = path; return @{@"_syncDeviceId": @"D1"};
}
- (void)consumeIncomingResponseForPath:(NSString *)path method:(NSString *)method response:(NSDictionary *)response {
    self.consumed = YES;
}
@end

@interface NoopFetching2 : NSObject <WPSyncFetching>
@end
@implementation NoopFetching2
- (void)fetchSource:(NSString *)source userId:(NSString *)userId deviceId:(NSString *)deviceId
        identifiers:(NSDictionary *)identifiers knobs:(WPSyncKnobs *)knobs weak:(BOOL)weak
               hint:(WPSyncFetchHint *)hint completion:(void (^)(BOOL))completion {}
@end

@interface WPSyncHookTests : XCTestCase
@end

@implementation WPSyncHookTests

- (void)tearDown { [WPSyncHook installObserver:nil]; }   // don't leak the process-wide observer

- (void)testInstallReplaceClear {
    XCTAssertNil([WPSyncHook observer]);             // inert by default
    RecordingObserver *a = [RecordingObserver new];
    [WPSyncHook installObserver:a];
    XCTAssertTrue([WPSyncHook observer] == a);
    RecordingObserver *b = [RecordingObserver new];
    [WPSyncHook installObserver:b];
    XCTAssertTrue([WPSyncHook observer] == b);        // replaced
    [WPSyncHook installObserver:nil];
    XCTAssertNil([WPSyncHook observer]);              // cleared -> inert again
}

- (void)testObserverIsInvoked {
    RecordingObserver *o = [RecordingObserver new];
    [WPSyncHook installObserver:o];
    NSDictionary *p = [[WPSyncHook observer] prepareOutgoingParamsForPath:@"/events" method:@"POST"];
    XCTAssertEqualObjects(o.lastPath, @"/events");
    XCTAssertEqualObjects(p[@"_syncDeviceId"], @"D1");
    [[WPSyncHook observer] consumeIncomingResponseForPath:@"/events" method:@"POST" response:@{}];
    XCTAssertTrue(o.consumed);
}

- (void)testWPSyncIsInstallableAsObserver {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.wonderpush.test.hook"];
    WPSync *sync = [[WPSync alloc] initWithStateStore:[[WPSyncStateStore alloc] initWithUserDefaults:d]
                                              fetcher:[NoopFetching2 new]];
    [WPSyncHook installObserver:sync];   // compiles only if WPSync conforms to WPSyncRequestObserver
    XCTAssertTrue([WPSyncHook observer] == sync);
    // A non-opportunistic path yields no params even through the seam.
    XCTAssertEqualObjects([[WPSyncHook observer] prepareOutgoingParamsForPath:@"/configuration" method:@"GET"], @{});
}

@end
