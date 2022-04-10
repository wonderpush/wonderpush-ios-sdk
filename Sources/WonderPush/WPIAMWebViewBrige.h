//
//  WPIAMWebViewBrige.h
//  WonderPush
//
//  Created by Prouha Kévin on 09/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMWebViewBrige : NSObject

- (void) onWPIAMWebViewDidReceivedMessage: (NSDictionary *) receivedMessageFromBridge with : (NSString *) methodName in: (WKWebView *) wkWebViewInstance;

@end

NS_ASSUME_NONNULL_END
