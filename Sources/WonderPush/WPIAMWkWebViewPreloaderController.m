//
//  WPIAMWkWebViewPreloaderController.m
//  WonderPush
//
//  Created by Prouha Kévin on 19/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPIAMWkWebViewPreloaderController.h"

@interface WPIAMWkWebViewPreloaderController () <WKNavigationDelegate>
@property (weak, nonatomic) IBOutlet WKWebView *wkWebView;

@property(atomic) Boolean webViewUrlLoadingCallbackHasBeenDone;
@property(atomic) void (^successWebViewUrlLoadingBlock)(WKWebView *);
@property(atomic) void (^errorWebViewUrlLoadingBlock)(NSError *);

@end

@implementation WPIAMWkWebViewPreloaderController

- (void) preLoadWebViewWith : (NSURL *) webViewURL
                           withSuccessCompletionHandler : (void (^)(WKWebView*)) successBlock
                           withErrorCompletionHander: (void (^)(NSError *)) errorBlock{
    
    //Loads the view controller’s view if it has not yet been loaded.
    [self loadViewIfNeeded];
    
    self.webViewUrlLoadingCallbackHasBeenDone = false;
    self.successWebViewUrlLoadingBlock = successBlock;
    self.errorWebViewUrlLoadingBlock = errorBlock;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.allowsInlineMediaPlayback = YES;
    
    self.wkWebView.navigationDelegate = self;
    
    NSURLRequest *requestToLoad = [NSURLRequest requestWithURL: webViewURL];
    [self.wkWebView loadRequest:requestToLoad];
}


- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.errorWebViewUrlLoadingBlock(error);
        self.webViewUrlLoadingCallbackHasBeenDone = true;
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (false == self.webViewUrlLoadingCallbackHasBeenDone){
        self.errorWebViewUrlLoadingBlock(error);
        self.webViewUrlLoadingCallbackHasBeenDone = true;
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    
    NSString *javascriptToInjectFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"webViewBridgeJavascriptFileToInject" ofType:@"js"];
    NSString* javascriptString = [NSString stringWithContentsOfFile:javascriptToInjectFile encoding:NSUTF8StringEncoding error:nil];
    [webView evaluateJavaScript:javascriptString completionHandler:nil];
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
        self.successWebViewUrlLoadingBlock(self.wkWebView);
        self.webViewUrlLoadingCallbackHasBeenDone = true;
    }
}
@end
