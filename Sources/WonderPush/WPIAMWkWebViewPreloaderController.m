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
@property(atomic, assign) BOOL webViewUrlLoadingCallbackDone;
@property(atomic, strong) void (^successWebViewUrlLoadingBlock)(WKWebView *);
@property(atomic, strong) void (^errorWebViewUrlLoadingBlock)(NSError *);

@end

API_AVAILABLE(ios(11.0))
static WKContentRuleList *blockWonderPushScriptContentRuleList = nil;

@implementation WPIAMWkWebViewPreloaderController

- (void) preLoadWebViewWith : (NSURL *) webViewURL
                           withSuccessCompletionHandler : (void (^)(WKWebView*)) successBlock
                           withErrorCompletionHander: (void (^)(NSError *)) errorBlock {
    
    //Loads the view controller’s view if it has not yet been loaded.
    [self loadViewIfNeeded];
    
    self.webViewUrlLoadingCallbackDone = NO;
    self.successWebViewUrlLoadingBlock = successBlock;
    self.errorWebViewUrlLoadingBlock = errorBlock;

    self.wkWebView.configuration.allowsInlineMediaPlayback = YES;
    self.wkWebView.navigationDelegate = self;
    
    // Install content blockers
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

- (void)reportFailWithError:(NSError *)error {
    if (!self.webViewUrlLoadingCallbackDone) {
        self.wkWebView.navigationDelegate = nil;
        self.webViewUrlLoadingCallbackDone = YES;
        self.errorWebViewUrlLoadingBlock(error);
    }
}

- (void)reportSuccess {
    if (!self.webViewUrlLoadingCallbackDone) {
        self.wkWebView.navigationDelegate = nil;
        self.webViewUrlLoadingCallbackDone = YES;
        self.successWebViewUrlLoadingBlock(self.wkWebView);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    //webview timeout of X seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, INAPP_WEBVIEW_LOAD_TIMEOUT_TIME_INTERVAL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                             code:IAMDisplayRenderErrorTypeTimeoutError
                                         userInfo:@{NSLocalizedDescriptionKey : @"Timeout exception occured to load webView url"}];
        [self reportFailWithError:error];
    });
}


- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    
    /*NSString *javascriptToInjectFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"webViewBridgeJavascriptFileToInject" ofType:@"js"];
    NSString* javascriptString = [NSString stringWithContentsOfFile:javascriptToInjectFile encoding:NSUTF8StringEncoding error:nil];
    [webView evaluateJavaScript:javascriptString completionHandler:nil];*/
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {

    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {

        NSHTTPURLResponse * response = (NSHTTPURLResponse *)navigationResponse.response;
        if (response.statusCode >= 400) {
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeHTTPError
                                             userInfo:@{NSLocalizedDescriptionKey : @"Bad response code"}];
            [self reportFailWithError:error];
            decisionHandler(WKNavigationResponsePolicyCancel);
            return;
        }

    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self reportSuccess];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                         code:IAMDisplayRenderErrorTypeUnspecifiedError
                                     userInfo:@{NSLocalizedDescriptionKey : @"Page load terminated"}];
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction didBecomeDownload:(WKDownload *)download  API_AVAILABLE(ios(14.5)) {
    [download cancel:^(NSData *data) {}];
    NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                         code:IAMDisplayRenderErrorTypeNavigationBecameDownloadError
                                     userInfo:@{NSLocalizedDescriptionKey : @"Navigation became download"}];
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView navigationResponse:(WKNavigationResponse *)navigationResponse didBecomeDownload:(WKDownload *)download  API_AVAILABLE(ios(14.5)) {
    [download cancel:^(NSData *data) {}];
    NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                         code:IAMDisplayRenderErrorTypeNavigationBecameDownloadError
                                     userInfo:@{NSLocalizedDescriptionKey : @"Navigation became download"}];
    [self reportFailWithError:error];
}

- (void)fetchRuleList:(void(^)(WKContentRuleList *list, NSError *error))handler  API_AVAILABLE(ios(11.0)) {
    if (blockWonderPushScriptContentRuleList) {
        handler(blockWonderPushScriptContentRuleList, nil);
        return;
    }
    // Create a rule-list that blocks requests to the in-app SDK javascript loader.
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
