//
//  WPIAMTemporaryStorage.h
//  WonderPush
//
//  Created by Stéphane JAIS on 13/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPIAMMessageDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMTemporaryStorage : NSObject
+ (instancetype) temporaryStorage;
- (void)handleNotification:(NSDictionary *)payload;
- (NSDictionary *)fetchResponse;
@end

NS_ASSUME_NONNULL_END
