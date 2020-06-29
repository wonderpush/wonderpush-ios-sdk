//
//  WPSPFieldSource.h
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPDataSource.h"
#import "WPSPFieldPath.h"
NS_ASSUME_NONNULL_BEGIN

@interface WPSPFieldSource : WPSPDataSource
@property (nonnull, readonly) WPSPFieldPath *path;

- (instancetype) initWithParent:(WPSPDataSource *)parent fieldPath:(WPSPFieldPath *)path;
@end

NS_ASSUME_NONNULL_END
