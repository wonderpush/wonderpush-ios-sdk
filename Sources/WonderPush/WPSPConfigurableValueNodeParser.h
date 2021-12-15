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

@interface WPSPConfigurableValueNodeParser : NSObject

- (void) registerExactNameParserWithKey:(NSString *)key parser:(WPSPASTValueNodeParser)parser;
- (void) registerDynamicNameParser:(WPSPASTValueNodeParser)parser;
- (WPSPASTValueNode * _Nullable) parseValueWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input;
@end

NS_ASSUME_NONNULL_END
