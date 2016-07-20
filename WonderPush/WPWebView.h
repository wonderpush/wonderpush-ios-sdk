//
//  WPWebView.h
//  WonderPush
//
//  Created by Olivier Favre on 13/06/16.
//  Copyright © 2016 WonderPush. All rights reserved.
//

#ifndef WPWebView_h
#define WPWebView_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "PKAlertController.h"

@interface WPWebView : UIWebView <UIWebViewDelegate, PKAlertViewLayoutAdapter>

@end

#endif /* WPWebView_h */
