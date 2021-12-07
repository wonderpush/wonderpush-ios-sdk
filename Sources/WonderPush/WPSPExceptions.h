//
//  WPSPExceptions.h
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPSPException : NSException
@end

@interface WPSPBadInputException : NSException
- (instancetype) initWithReason:(NSString * _Nullable)reason;
@end

@interface WPSPUnknownCriterionException : NSException
- (instancetype) initWithReason:(NSString * _Nullable)reason;
@end

@interface WPSPUnknownValueException : NSException
- (instancetype) initWithReason:(NSString * _Nullable)reason;
@end


NS_ASSUME_NONNULL_END
