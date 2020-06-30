//
//  WPSegmentationDSLParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPParserConfig.h"
#import "WPSPASTCriterionNode.h"
#import "WPSPParsingContext.h"
#import "WPSPDataSource.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPSegmentationDSLParser : NSObject
@property (nonnull, readonly) WPSPParserConfig *parserConfig;

+ (instancetype) defaultParser;
+ (instancetype) defaultThrowingParser;

- (instancetype) initWithParserConfig:(WPSPParserConfig *)parserConfig;
- (WPSPASTCriterionNode *) parse:(NSDictionary *)input dataSource:(WPSPDataSource *)dataSource;
- (WPSPASTCriterionNode *) parseCriterionWithContext:(WPSPParsingContext *)context input:(NSDictionary *)input;
- (WPSPASTValueNode *) parseValueWithContext:(WPSPParsingContext *)context input:(id)input;

@end

NS_ASSUME_NONNULL_END
