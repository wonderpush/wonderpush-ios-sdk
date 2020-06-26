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

@interface WPSPConfigurableCriterionNodeParser : NSObject <WPSPASTCriterionNodeParser>

- (void) registerExactNameParserWithKey:(NSString *)key parser:(id<WPSPASTCriterionNodeParser>)parser;
- (void) registerDynamicNameParser:(id<WPSPASTCriterionNodeParser>)parser;

@end

NS_ASSUME_NONNULL_END
