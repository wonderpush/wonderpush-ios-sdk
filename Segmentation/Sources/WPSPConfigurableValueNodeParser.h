//
//  WPSPConfigurableValueNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPASTValueNodeParser.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPConfigurableValueNodeParser : NSObject <WPSPASTValueNodeParser>

- (void) registerExactNameParserWithKey:(NSString *)key parser:(id<WPSPASTValueNodeParser>)parser;
- (void) registerDynamicNameParser:(id<WPSPASTValueNodeParser>)parser;

@end

NS_ASSUME_NONNULL_END
