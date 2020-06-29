//
//  WPASTCriterionNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPParsingContext.h"
#import "WPSPASTCriterionNode.h"

NS_ASSUME_NONNULL_BEGIN

typedef WPSPASTCriterionNode * _Nullable(^WPSPASTCriterionNodeParser)(WPSPParsingContext *, NSString *, id);

#define CRITERION_NODE_PARSER_BLOCK(code) ^WPSPASTCriterionNode * _Nullable (WPSPParsingContext *context, NSString *key, id input) { \
code \
}

NS_ASSUME_NONNULL_END
