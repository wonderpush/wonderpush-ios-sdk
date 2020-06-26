//
//  WPASTValueNodeParser.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WPSPASTValueNode;
@class WPSPParsingContext;
@protocol WPSPASTValueNodeParser <NSObject>
- (WPSPASTValueNode * _Nullable) parseValueWithContext:(WPSPParsingContext *)context key:(NSString *)key input:(id)input;
@end

NS_ASSUME_NONNULL_END
