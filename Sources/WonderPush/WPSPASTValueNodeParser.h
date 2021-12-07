//
//  WPASTValueNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPASTValueNode.h"
#import "WPSPParsingContext.h"
NS_ASSUME_NONNULL_BEGIN

typedef WPSPASTValueNode * _Nullable(^WPSPASTValueNodeParser)(WPSPParsingContext *, NSString *, id);

#define VALUE_NODE_PARSER_BLOCK ^WPSPASTValueNode * _Nullable (WPSPParsingContext *context, NSString *key, id input)
NS_ASSUME_NONNULL_END
