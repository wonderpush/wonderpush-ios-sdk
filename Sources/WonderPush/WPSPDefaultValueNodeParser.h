//
//  WPSPDefaultValueNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPConfigurableValueNodeParser.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPDefaultValueNodeParser : WPSPConfigurableValueNodeParser

+ (NSDate * _Nullable) parseAbsoluteDate:(NSString *)input;

/// The parser registered under the "date" key: parses a raw number/string as an absolute or relative
/// date, producing a WPSPDateValueNode/WPSPRelativeDateValueNode. Exposed so callers (e.g. the
/// Segmenter's date-coercion of raw field values) can reuse the exact same date parsing logic.
+ (WPSPASTValueNodeParser) parseDate;

@end

NS_ASSUME_NONNULL_END
