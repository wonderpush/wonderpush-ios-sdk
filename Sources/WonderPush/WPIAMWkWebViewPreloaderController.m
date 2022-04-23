//
//  WPIAMWkWebViewPreloaderController.m
//  WonderPush
//
//  Created by Prouha Kévin on 19/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPIAMWkWebViewPreloaderController.h"
#import "WPLog.h"
#import "WonderPush_constants.h"
#import "WPCore+InAppMessagingDisplay.h"
#import "WPInAppMessagingRendering.h"

@interface WPIAMWkWebViewPreloaderController () <WKNavigationDelegate>
@property (weak, nonatomic) IBOutlet WKWebView *wkWebView;

@property(atomic) Boolean webViewUrlLoadingCallbackHasBeenDone;
@property(atomic) void (^successWebViewUrlLoadingBlock)(WKWebView *);
@property(atomic) void (^errorWebViewUrlLoadingBlock)(NSError *);

@end

API_AVAILABLE(ios(11.0))
static WKContentRuleList *blockWonderPushScriptContentRuleList = nil;

@implementation WPIAMWkWebViewPreloaderController

- (void) preLoadWebViewWith : (NSURL *) webViewURL
                           withSuccessCompletionHandler : (void (^)(WKWebView*)) successBlock
                           withErrorCompletionHander: (void (^)(NSError *)) errorBlock{
    
    //Loads the view controller’s view if it has not yet been loaded.
    [self loadViewIfNeeded];
    
    self.webViewUrlLoadingCallbackHasBeenDone = false;
    self.successWebViewUrlLoadingBlock = successBlock;
    self.errorWebViewUrlLoadingBlock = errorBlock;

    self.wkWebView.configuration.allowsInlineMediaPlayback = YES;
    self.wkWebView.navigationDelegate = self;
    
    if (@available(iOS 11.0, *)) {
        [self fetchRuleList:^(WKContentRuleList *list, NSError *error) {
            if (list) {
                [self.wkWebView.configuration.userContentController addContentRuleList:list];
            }
            NSURLRequest *requestToLoad = [NSURLRequest requestWithURL: webViewURL];
            [self.wkWebView loadRequest:requestToLoad];
        }];
    } else {
        NSURLRequest *requestToLoad = [NSURLRequest requestWithURL: webViewURL];
        [self.wkWebView loadRequest:requestToLoad];
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    //webview timeout of 2 seconds
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
       if (false == self.webViewUrlLoadingCallbackHasBeenDone){
           self.webViewUrlLoadingCallbackHasBeenDone = true;
           self.errorWebViewUrlLoadingBlock([NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                                code:IAMDisplayRenderErrorTypeUnspecifiedError
                                                            userInfo:@{@"message" : @"Timeout exception occured to load webView url"}]);
       }
   });
}


- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.webViewUrlLoadingCallbackHasBeenDone = true;
        self.errorWebViewUrlLoadingBlock(error);
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.webViewUrlLoadingCallbackHasBeenDone = true;
        self.errorWebViewUrlLoadingBlock(error);
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    
    /*NSString *javascriptToInjectFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"webViewBridgeJavascriptFileToInject" ofType:@"js"];
    NSString* javascriptString = [NSString stringWithContentsOfFile:javascriptToInjectFile encoding:NSUTF8StringEncoding error:nil];
    [webView evaluateJavaScript:javascriptString completionHandler:nil];*/
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {

    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {

        NSHTTPURLResponse * response = (NSHTTPURLResponse *)navigationResponse.response;
        if (response.statusCode >= 400) {

            decisionHandler(WKNavigationResponsePolicyCancel);
            return;
        }

    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.webViewUrlLoadingCallbackHasBeenDone = true;
        self.successWebViewUrlLoadingBlock(self.wkWebView);
    }
}

- (void)fetchRuleList:(void(^)(WKContentRuleList *list, NSError *error))handler  API_AVAILABLE(ios(11.0)) {
    if (blockWonderPushScriptContentRuleList) {
        handler(blockWonderPushScriptContentRuleList, nil);
        return;
    }
    NSString *scriptUrlString = INAPP_SDK_URL_REGEX;
    id ruleListJson = @[
        @{
            @"trigger": @{@"url-filter": scriptUrlString},
            @"action": @{@"type": @"block"},
        }
    ];
    NSString *ruleListJsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:ruleListJson options:0 error:nil] encoding:NSUTF8StringEncoding];
    [WKContentRuleListStore.defaultStore compileContentRuleListForIdentifier:@"BlockWonderPushInAppSDKScript" encodedContentRuleList:ruleListJsonString completionHandler:^(WKContentRuleList *list, NSError *error){
        if (error) {
            WPLog(@"Failed to create content rule list to block WonderPush in-app SDK script loading");
        }
        blockWonderPushScriptContentRuleList = list;
        handler(list, error);
    }];
}
@end
