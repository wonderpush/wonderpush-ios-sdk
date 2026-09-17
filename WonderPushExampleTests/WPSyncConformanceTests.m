//
//  WPSyncConformanceTests.m
//  WonderPushExampleTests
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The sdk-sync conformance harness (issue wonderpush-ios-sdk-i2x.11).
//
// Loads the language-neutral vector fixtures vendored under sync-conformance/ (generated from the JS
// reference SDK; see sync-conformance/PIN.txt for the pinned spec revision) and runs each case
// against the iOS ports, asserting the exact reference output. This turns cross-SDK behavioural
// consistency into a mechanical CI gate: if a vendored vector drifts from the iOS behaviour, CI fails.
//
// Encoding conventions (sync-conformance/README.md): Infinity/-Infinity/NaN are JSON strings and are
// mapped back to doubles here; null is the null-missing sentinel (NSNull); computeBackoffSleep is a
// double compared within a relative epsilon.

#import <XCTest/XCTest.h>
#import "WPSyncVersionId.h"
#import "WPSyncKnobs.h"
#import "WPSyncFetchPolicy.h"
#import "WPSyncProcessor.h"
#import "WPSyncResponseBlock.h"
#import "WPSyncSourceState.h"
#import "WPSyncDecision.h"
#import "WPSyncContactStore.h"

@interface WPSyncConformanceTests : XCTestCase
@end

@implementation WPSyncConformanceTests

#pragma mark - loading helpers

- (NSDictionary *)loadJSON:(NSString *)filename {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *url = [bundle URLForResource:[filename stringByDeletingPathExtension]
                          withExtension:[filename pathExtension]];
    XCTAssertNotNil(url, @"vendored conformance file not found in test bundle: %@ "
                          "(is it added to the WonderPushExampleTests Resources build phase?)", filename);
    if (!url) return nil;
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:&error];
    XCTAssertNotNil(json, @"failed to parse %@: %@", filename, error);
    return json;
}

- (NSArray *)casesOf:(NSString *)filename {
    return [self loadJSON:filename][@"cases"];
}

/// Map the "Infinity" / "-Infinity" / "NaN" JSON string sentinels back to doubles, recursively.
- (id)mapInfinities:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        if ([value isEqualToString:@"Infinity"]) return @(INFINITY);
        if ([value isEqualToString:@"-Infinity"]) return @(-INFINITY);
        if ([value isEqualToString:@"NaN"]) return @(NAN);
        return value;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        for (id key in value) out[key] = [self mapInfinities:value[key]];
        return out;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
        for (id e in value) [out addObject:[self mapInfinities:e]];
        return out;
    }
    return value;
}

/// JSON null (NSNull) and missing -> nil; otherwise pass through.
static id _Nullable orNil(id _Nullable v) { return (v == nil || v == [NSNull null]) ? nil : v; }

#pragma mark - provenance cross-checks

- (void)testIndexReferencesLoadableFiles {
    NSDictionary *files = [self loadJSON:@"index.json"][@"files"];
    XCTAssertGreaterThan(files.count, (NSUInteger)0);
    for (NSString *fn in files) {
        XCTAssertNotNil([self loadJSON:files[fn][@"file"]][@"cases"], @"%@", files[fn][@"file"]);
    }
}

- (void)testVendoredDefaultKnobsMatchPort {
    NSDictionary *vendored = [self mapInfinities:[self loadJSON:@"default-knobs.json"][@"defaultKnobs"]];
    XCTAssertEqualObjects([WPSyncKnobs defaultKnobs], [WPSyncKnobs knobsWithDictionary:vendored]);
}

#pragma mark - compareVersionId / acceptsResponse

- (void)testVectorsCompareVersionId {
    for (NSDictionary *c in [self casesOf:@"compare-version-id.vectors.json"]) {
        NSComparisonResult r = [WPSyncVersionId compareVersionId:c[@"input"][@"a"] with:c[@"input"][@"b"]];
        XCTAssertEqual((NSInteger)r, [c[@"expected"] integerValue], @"%@", c[@"name"]);
    }
}

- (void)testVectorsAcceptsResponse {
    for (NSDictionary *c in [self casesOf:@"accepts-response.vectors.json"]) {
        NSDictionary *resp = c[@"input"][@"response"], *st = c[@"input"][@"state"];
        BOOL r = [WPSyncVersionId acceptsResponseWithVersion:[resp[@"version"] longLongValue]
                                                   versionId:resp[@"versionId"]
                                                    readDate:[resp[@"readDate"] longLongValue]
                                                        data:resp[@"data"]
                                                 lastVersion:[st[@"lastVersion"] longLongValue]
                                               lastVersionId:st[@"lastVersionId"]
                                                lastReadDate:[st[@"lastReadDate"] longLongValue]];
        XCTAssertEqual(r, [c[@"expected"] boolValue], @"%@", c[@"name"]);
    }
}

#pragma mark - classifyResponse / processSourceBlock

- (void)testVectorsClassifyResponse {
    for (NSDictionary *c in [self casesOf:@"classify-response.vectors.json"]) {
        WPSyncResponseClassification *cl = [WPSyncProcessor classifyResponsePath:orNil(c[@"input"][@"path"])
                                                                          method:orNil(c[@"input"][@"method"])];
        XCTAssertEqualObjects([cl toDictionary], c[@"expected"], @"%@", c[@"name"]);
    }
}

- (void)testVectorsProcessSourceBlock {
    for (NSDictionary *c in [self casesOf:@"process-source-block.vectors.json"]) {
        id blockVal = c[@"input"][@"block"];
        WPSyncResponseBlock *block = (blockVal == [NSNull null]) ? nil : [WPSyncResponseBlock blockWithDictionary:blockVal];
        WPSyncSourceState *state = [WPSyncSourceState stateWithDictionary:c[@"input"][@"state"]];
        WPSyncDecision *d = [WPSyncProcessor processSourceBlock:block
                                                     serverTime:orNil(c[@"input"][@"serverTime"])
                                                          state:state
                                                           mode:c[@"input"][@"mode"]];
        XCTAssertEqualObjects([d toDictionary], c[@"expected"], @"%@", c[@"name"]);
    }
}

#pragma mark - fetch policy

- (void)testVectorsComputeBackoffSleep {
    for (NSDictionary *c in [self casesOf:@"compute-backoff-sleep.vectors.json"]) {
        WPSyncKnobs *k = [WPSyncKnobs knobsWithDictionary:c[@"input"][@"knobs"]];
        double r = [WPSyncFetchPolicy computeBackoffSleepWithAttemptCount:[c[@"input"][@"attemptCount"] integerValue]
                                                                     rand:[c[@"input"][@"rand"] doubleValue]
                                                                    knobs:k];
        double expected = [c[@"expected"] doubleValue];
        XCTAssertEqualWithAccuracy(r, expected, fabs(expected) * 1e-6 + 1e-9, @"%@", c[@"name"]);
    }
}

- (void)testVectorsShouldDebounceWeakSignal {
    for (NSDictionary *c in [self casesOf:@"should-debounce-weak-signal.vectors.json"]) {
        NSDictionary *in = c[@"input"];
        BOOL r = [WPSyncFetchPolicy shouldDebounceWeakSignalAtNow:[in[@"now"] longLongValue]
                                          lastFetchAttemptedDate:[in[@"lastFetchAttemptedDate"] longLongValue]
                                                      debounceMs:[in[@"debounceMs"] doubleValue]];
        XCTAssertEqual(r, [c[@"expected"] boolValue], @"%@", c[@"name"]);
    }
}

- (void)testVectorsShouldRateLimitSource {
    for (NSDictionary *c in [self casesOf:@"should-rate-limit-source.vectors.json"]) {
        NSDictionary *in = c[@"input"];
        BOOL r = [WPSyncFetchPolicy shouldRateLimitSourceAtNow:[in[@"now"] longLongValue]
                                       lastFetchAttemptedDate:[in[@"lastFetchAttemptedDate"] longLongValue]
                                                minIntervalMs:[in[@"minIntervalMs"] doubleValue]];
        XCTAssertEqual(r, [c[@"expected"] boolValue], @"%@", c[@"name"]);
    }
}

#pragma mark - knobs merge / staleness

- (void)testVectorsMergeKnobs {
    for (NSDictionary *c in [self casesOf:@"merge-knobs.vectors.json"]) {
        WPSyncKnobs *defaults = [WPSyncKnobs knobsWithDictionary:[self mapInfinities:c[@"input"][@"defaults"]]];
        WPSyncKnobs *r = [WPSyncKnobs mergeKnobsFromDefaults:defaults remoteConfig:orNil(c[@"input"][@"data"])];
        WPSyncKnobs *expected = [WPSyncKnobs knobsWithDictionary:[self mapInfinities:c[@"expected"]]];
        XCTAssertEqualObjects(r, expected, @"%@", c[@"name"]);
    }
}

- (void)testVectorsIsStateStale {
    for (NSDictionary *c in [self casesOf:@"is-state-stale.vectors.json"]) {
        WPSyncSourceState *st = [WPSyncSourceState stateWithDictionary:c[@"input"][@"state"]];
        WPSyncKnobs *k = [WPSyncKnobs knobsWithDictionary:[self mapInfinities:c[@"input"][@"knobs"]]];
        BOOL r = [WPSyncKnobs isStateStale:st knobs:k now:[c[@"input"][@"now"] longLongValue]];
        XCTAssertEqual(r, [c[@"expected"] boolValue], @"%@", c[@"name"]);
    }
}

#pragma mark - contact store

- (void)testVectorsContactStore {
    for (NSDictionary *c in [self casesOf:@"contact-store.vectors.json"]) {
        NSDictionary *in = c[@"input"];
        NSString *op = in[@"op"];
        id current = orNil(in[@"current"]);
        id arg = orNil(in[@"arg"]);
        NSDictionary *r = nil;
        if ([op isEqualToString:@"applyContactData"]) {
            r = [WPSyncContactStore applyContactData:current data:arg];
        } else if ([op isEqualToString:@"applyContactDelta"]) {
            r = [WPSyncContactStore applyContactDelta:current delta:arg];
        } else if ([op isEqualToString:@"clearContact"]) {
            r = [WPSyncContactStore clearContact];
        } else {
            XCTFail(@"unknown contact-store op: %@", op);
        }
        XCTAssertEqualObjects(r, orNil(c[@"expected"]), @"%@", c[@"name"]);
    }
}

@end
