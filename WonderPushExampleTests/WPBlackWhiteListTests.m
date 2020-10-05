//
//  WPBlackWhiteListTests.m
//  WonderPushExampleTests
//
//  Created by Stéphane JAIS on 05/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPBlackWhiteList.h"

@interface WPBlackWhiteListTests : XCTestCase

@end

@implementation WPBlackWhiteListTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testParseMinus {
    WPBlackWhiteList *blackWhiteList = [[WPBlackWhiteList alloc] initWithRules:@[@"plus", @"-minus", @"-minus", @"plus"] ];
    NSArray<NSString *> *expectedBlackList = @[ @"minus", @"minus"];
    NSArray<NSString *> *expectedWhiteList = @[ @"plus", @"plus"];
    XCTAssertEqualObjects(expectedWhiteList, blackWhiteList.whiteList);
    XCTAssertEqualObjects(expectedBlackList, blackWhiteList.blackList);
}

- (void)testItemMatches {
    XCTAssertTrue([WPBlackWhiteList item:@"foo" matches:@"*"]);
    XCTAssertTrue([WPBlackWhiteList item:@"" matches:@"*"]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertFalse([WPBlackWhiteList item:nil matches:@"*"]);
    XCTAssertFalse([WPBlackWhiteList item:@"toto" matches:nil]);
#pragma clang diagnostic pop
    
    XCTAssertTrue([WPBlackWhiteList item:@"foo" matches:@"foo*"]);
    XCTAssertTrue([WPBlackWhiteList item:@"foobar" matches:@"foo*"]);
    XCTAssertFalse([WPBlackWhiteList item:@"barfoo" matches:@"foo*"]);

    XCTAssertTrue([WPBlackWhiteList item:@"foo" matches:@"*foo"]);
    XCTAssertFalse([WPBlackWhiteList item:@"foobar" matches:@"*foo"]);
    XCTAssertTrue([WPBlackWhiteList item:@"barfoo" matches:@"*foo"]);

    XCTAssertTrue([WPBlackWhiteList item:@"foo" matches:@"*foo*"]);
    XCTAssertTrue([WPBlackWhiteList item:@"foobar" matches:@"*foo*"]);
    XCTAssertTrue([WPBlackWhiteList item:@"barfoo" matches:@"*foo*"]);
    XCTAssertFalse([WPBlackWhiteList item:@"bar" matches:@"*foo*"]);
    XCTAssertFalse([WPBlackWhiteList item:@"fobaro" matches:@"*foo*"]);

    XCTAssertFalse([WPBlackWhiteList item:@"foo" matches:@"foo*bar"]);
    XCTAssertFalse([WPBlackWhiteList item:@"barfoo" matches:@"foo*bar"]);
    XCTAssertTrue([WPBlackWhiteList item:@"fooobar" matches:@"foo*bar"]);
    XCTAssertTrue([WPBlackWhiteList item:@"foobar" matches:@"foo*bar"]);
    XCTAssertFalse([WPBlackWhiteList item:@"foobarbaz" matches:@"foo*bar"]);
    XCTAssertFalse([WPBlackWhiteList item:@"bazfoobar" matches:@"foo*bar"]);

    XCTAssertTrue([WPBlackWhiteList item:@"foobarbaz" matches:@"foo*bar*baz"]);
    XCTAssertTrue([WPBlackWhiteList item:@"foo123bar123baz" matches:@"foo*bar*baz"]);
    XCTAssertFalse([WPBlackWhiteList item:@"foo1bar1baz1" matches:@"foo*bar*baz"]);
    XCTAssertFalse([WPBlackWhiteList item:@"1foo1bar1baz" matches:@"foo*bar*baz"]);

    XCTAssertTrue([WPBlackWhiteList item:@"foo...totobar" matches:@"foo...*bar"]);
    XCTAssertTrue([WPBlackWhiteList item:@"foo...bar" matches:@"foo...*bar"]);
    XCTAssertFalse([WPBlackWhiteList item:@"fooabcbar" matches:@"foo...*bar"]);
    XCTAssertFalse([WPBlackWhiteList item:@"foo...bar1" matches:@"foo...*bar"]);
}

- (void)testAllow {
    WPBlackWhiteList *blackWhiteList;
    
    // "*" in the white list disallows everything, except those in the whitelist
    blackWhiteList = [[WPBlackWhiteList alloc] initWithRules:@[@"-*", @"@APP_OPEN", @"@PRESENCE"]];
    
    XCTAssertTrue([blackWhiteList allow:@"@APP_OPEN"]);
    XCTAssertTrue([blackWhiteList allow:@"@PRESENCE"]);
    XCTAssertFalse([blackWhiteList allow:@"foo"]);
    XCTAssertFalse([blackWhiteList allow:@"bar"]);

    // "*" in the white list allows everything, no exception
    blackWhiteList = [[WPBlackWhiteList alloc] initWithRules:@[@"*", @"-@APP_OPEN", @"-@PRESENCE"]];
    
    XCTAssertTrue([blackWhiteList allow:@"@APP_OPEN"]);
    XCTAssertTrue([blackWhiteList allow:@"@PRESENCE"]);
    XCTAssertTrue([blackWhiteList allow:@"foo"]);
    XCTAssertTrue([blackWhiteList allow:@"bar"]);

    // some black, some white
    blackWhiteList = [[WPBlackWhiteList alloc] initWithRules:@[@"@PRESENCE", @"-@APP_OPEN"]];
    
    XCTAssertFalse([blackWhiteList allow:@"@APP_OPEN"]);
    XCTAssertTrue([blackWhiteList allow:@"@PRESENCE"]);
    XCTAssertTrue([blackWhiteList allow:@"foo"]);
    XCTAssertTrue([blackWhiteList allow:@"bar"]);

    // some black, some white
    blackWhiteList = [[WPBlackWhiteList alloc] initWithRules:@[@"sometoto", @"-some*"]];
    
    XCTAssertFalse([blackWhiteList allow:@"sometiti"]);
    XCTAssertTrue([blackWhiteList allow:@"sometoto"]);
    XCTAssertFalse([blackWhiteList allow:@"some"]);
}

@end
