//
//  WPSPParserConfig.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPASTValueNodeParser.h"
#import "WPSPASTCriterionNodeParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPParserConfig : NSObject
@property (nonnull, readonly) id<WPSPASTValueNodeParser> valueParser;
@property (nonnull, readonly) id<WPSPASTCriterionNodeParser> criterionParser;
@property (readonly) BOOL throwOnUnknownCriterion;
@property (readonly) BOOL throwOnUnknownValue;
- (instancetype) initWithValueParser:(id<WPSPASTValueNodeParser>)valueParser
                     criterionParser:(id<WPSPASTCriterionNodeParser>)criterionParser
             throwOnUnknownCriterion:(BOOL)throwOnUnknownCriterion
                 throwOnUnknownValue:(BOOL)throwOnUnknownValue;
- (instancetype) initWithValueParser:(id<WPSPASTValueNodeParser>)valueParser
                     criterionParser:(id<WPSPASTCriterionNodeParser>)criterionParser;
@end

NS_ASSUME_NONNULL_END
