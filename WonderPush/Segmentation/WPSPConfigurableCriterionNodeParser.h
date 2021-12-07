//
//  WPSPConfigurableCriterionNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPASTCriterionNodeParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPConfigurableCriterionNodeParser : NSObject

- (void) registerExactNameParserWithKey:(NSString *)key parser:(WPSPASTCriterionNodeParser)parser;
- (void) registerDynamicNameParser:(WPSPASTCriterionNodeParser)parser;
- (WPSPASTCriterionNode * _Nullable) parseCriterionWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input;
@end

NS_ASSUME_NONNULL_END
