//
//  WPAction.h
//  WonderPush
//
//  Created by Stéphane JAIS on 19/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Defines the metadata for a IAM action.
 */
NS_SWIFT_NAME(Action)
@interface WPAction : NSObject

/**
 * The URL to follow if the action is clicked.
 */
@property(nonatomic, nullable, copy, readonly) NSURL *targetUrl;

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
