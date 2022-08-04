//
//  WPIAMWebView.m
//  WonderPush
//
//  Created by Stéphane JAIS on 01/06/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPIAMWebView.h"
#import <WonderPushCommon/WPLog.h>
#import "WPCore+InAppMessagingDisplay.h"
#import "WonderPush_constants.h"
#import "WonderPush_private.h"
#import "WPURLFollower.h"
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPIAMWebViewBridge: NSObject<WKScriptMessageHandler, WKUIDelegate>
@property (nonatomic, weak) WPIAMWebView *webView;
@end

@interface WPIAMWebViewNavigationDelegate: NSObject<WKNavigationDelegate>
@property (nonatomic, weak) WPIAMWebView *webView;
@property(atomic, assign) BOOL webViewUrlLoadingCallbackDone;
@end

@interface WPIAMBoolResult : NSObject
+ (instancetype) yes;
+ (instancetype) no;
+ (instancetype) with:(BOOL)val;
@end

@interface WPIAMWebView ()
@property (nonatomic, strong) WPIAMWebViewBridge *bridge;
@property (nonatomic, strong) WPIAMWebViewNavigationDelegate *navDelegate;
@property (nonatomic, strong) NSURL *initialURL;
@end

NS_ASSUME_NONNULL_END

API_AVAILABLE(ios(11.0))
static WKContentRuleList *blockWonderPushScriptContentRuleList = nil;

@implementation WPIAMBoolResult

+ (instancetype)yes {
    static WPIAMBoolResult *result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [WPIAMBoolResult new];
    });
    return result;
}

+ (instancetype)no {
    static WPIAMBoolResult *result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [WPIAMBoolResult new];
    });
    return result;
}

+ (instancetype)with:(BOOL)val {
    if (val) return WPIAMBoolResult.yes;
    return WPIAMBoolResult.no;
}
@end

@implementation WPIAMWebView

+ (void)initialize {
    [self ensureInitialized];
}

+ (void)ensureInitialized {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(iOS 11.0, *)) {
            // Create a rule-list that blocks requests to the in-app SDK javascript loader.
            NSString *scriptUrlString = INAPP_SDK_URL_REGEX;
            id ruleListJson = @[
                @{
                    @"trigger": @{@"url-filter": scriptUrlString},
                    @"action": @{@"type": @"block"},
                }
            ];
            NSString *ruleListJsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:ruleListJson options:0 error:nil] encoding:NSUTF8StringEncoding];
            [WKContentRuleListStore.defaultStore compileContentRuleListForIdentifier:@"BlockWonderPushInAppSDKScript" encodedContentRuleList:ruleListJsonString completionHandler:^(WKContentRuleList *list, NSError *error) {
                if (error) {
                    WPLog(@"Failed to create content rule list to block WonderPush in-app SDK script loading: %@", error);
                }
                blockWonderPushScriptContentRuleList = list;
            }];
        }
    });
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (!self.initialURL) {
        self.initialURL = request.URL;
    }
    return [super loadRequest:request];
}

- (void) installEnvironment {
    // Install content blockers
    if (@available(iOS 11.0, *)) {
        if (blockWonderPushScriptContentRuleList) {
            [self.configuration.userContentController addContentRuleList:blockWonderPushScriptContentRuleList];
        }
    }

    // Install bridge
    if (!self.bridge) {
        self.bridge = [WPIAMWebViewBridge new];
        self.bridge.webView = self;
        self.UIDelegate = self.bridge;
    }

    // Install navigation delegate
    if (!self.navDelegate) {
        self.navDelegate = [WPIAMWebViewNavigationDelegate new];
        self.navDelegate.webView = self;
        [super setNavigationDelegate:self.navDelegate];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        [self installEnvironment];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self installEnvironment];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if (self = [super initWithFrame:frame configuration:configuration]) {
        [self installEnvironment];
    }
    return self;
}

- (void)setNavigationDelegate:(id<WKNavigationDelegate>)navigationDelegate {
    WPLog(@"Error: cannot override navigation delegate for WPIAMWebView");
}

@end

@implementation WPIAMWebViewBridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {

    if([message.body isKindOfClass:[NSDictionary class]]) {
        NSString *method = message.body[@"method"];
        NSArray *args = message.body[@"args"];
        NSString *callId = message.body[@"callId"];
        if (![method isKindOfClass:NSString.class]
            || ![args isKindOfClass:NSArray.class]
            || ![callId isKindOfClass:NSString.class]) {
            WPLog(@"Invalid message sent to WonderPushInAppSDK: %@", message);
            return;
        }
        [self callMethod:method withArgs:args callId:callId];
    }
}

+ (NSString *)serialize:(id)obj error:(NSError **)err {
    if (obj == nil) return @"undefined";
    if (obj == WPIAMBoolResult.yes) return @"true";
    if (obj == WPIAMBoolResult.no) return @"false";
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingFragmentsAllowed error:err];
    if (*err) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)resolve:(id)result callId:(NSString *)callId {
    if (!callId) return;
    NSError *error = nil;
    NSString *resultString = [WPIAMWebViewBridge serialize:result error:&error];
    if (error) {
        WPLog(@"Could not convert result to JSON: %@", error);
        return;
    }
    NSString *callIdString = [WPIAMWebViewBridge serialize:callId error:&error];
    if (error) {
        WPLog(@"Could not convert callId to JSON: %@", error);
        return;
    }

    NSString *script = [NSString stringWithFormat:@"window.WonderPushInAppSDK.resolve(%@, %@);", resultString, callIdString];
    [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) {
            WPLog(@"Error evaluation javascript code: %@", error);
        }
    }];
}

- (void)reject:(NSError *)rejectionError callId:(NSString *)callId {
    NSError *error = nil;
    NSString *errorString = [WPIAMWebViewBridge serialize:rejectionError.localizedDescription error:&error];
    if (error) {
        WPLog(@"Could not convert result to JSON: %@", error);
        return;
    }
    NSString *callIdString = [WPIAMWebViewBridge serialize:callId error:&error];
    if (error) {
        WPLog(@"Could not convert callId to JSON: %@", error);
        return;
    }
    NSString *script = [NSString stringWithFormat:@"window.WonderPushInAppSDK.reject(new Error(%@), %@);", errorString, callIdString];
    [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) {
            WPLog(@"Error evaluation javascript code: %@", error);
        }
    }];
}

-(void) callMethod:(NSString *)methodName withArgs:(NSArray *)args callId:(NSString *)callId {
    if ([methodName isEqualToString:@"dismiss"]) {
        if (self.webView.onDismiss) {
            self.webView.onDismiss(WPInAppMessagingDismissTypeUserTapClose);
        }
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqualToString:@"trackClick"]) {
        NSString *buttonLabel = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        if (!buttonLabel) {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"buttonLabel cannot be null", nil),
            }] callId:callId];
            return;
        }
        [self.webView.controllerDelegate trackClickWithMessage:self.webView.inAppMessage buttonLabel:buttonLabel];
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqual:@"getPayload"]) {
        [self getPayload:callId];
    }
    else if ([methodName isEqual:@"openDeepLink"]) {
        [self openDeepLink:args callId:callId];
    }
    else if ([methodName isEqual:@"openExternalUrl"]) {
        [self openExternalUrl:args callId:callId];
    }
    else if ([methodName isEqual:@"triggerLocationPrompt"]) {
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusAuthorizedAlways:
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                [self resolve:WPIAMBoolResult.yes callId:callId];
                return;
            case kCLAuthorizationStatusDenied:
                [self resolve:WPIAMBoolResult.no callId:callId];
                return;
            default:
                break;
        }

        [WonderPush triggerLocationPrompt];
        __weak WPIAMWebViewBridge *weakSelf = self;
        id __block token = [NSNotificationCenter.defaultCenter
                            addObserverForName:UIApplicationDidBecomeActiveNotification
                            object:nil
                            queue:nil
                            usingBlock:^(NSNotification *note) {
            [NSNotificationCenter.defaultCenter removeObserver:token];
            WPIAMBoolResult *result;
            switch ([CLLocationManager authorizationStatus]) {
                case kCLAuthorizationStatusAuthorizedAlways:
                case kCLAuthorizationStatusAuthorizedWhenInUse:
                    result = WPIAMBoolResult.yes;
                    break;
                default:
                    result = WPIAMBoolResult.no;
                    break;
            }
            [weakSelf resolve:result callId:callId];
        }];
    }
    else if ([methodName isEqual:@"subscribeToNotifications"]) {
        [WonderPush subscribeToNotifications];
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqual:@"unsubscribeFromNotifications"]) {
        [WonderPush unsubscribeFromNotifications];
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqual:@"isSubscribedToNotifications"]) {
        [self resolve:[WPIAMBoolResult with:[WonderPush isSubscribedToNotifications]] callId:callId];
    }
    else if ([methodName isEqual:@"getUserId"]) {
        [self resolve:[WonderPush userId] callId:callId];
    }
    else if ([methodName isEqual:@"getInstallationId"]) {
        [self resolve:[WonderPush installationId] callId:callId];
    }
    else if ([methodName isEqual:@"getCountry"]) {
        [self resolve:[WonderPush country] callId:callId];
    }
    else if ([methodName isEqual:@"getCurrency"]) {
        [self resolve:[WonderPush currency] callId:callId];
    }
    else if ([methodName isEqual:@"getLocale"]) {
        [self resolve:[WonderPush locale] callId:callId];
    }
    else if ([methodName isEqual:@"getTimeZone"]) {
        [self resolve:[WonderPush timeZone] callId:callId];
    }
    else if ([methodName isEqual:@"getDevicePlatform"]) {
        [self resolve:@"iOS" callId:callId];
    } else if ([methodName isEqual:@"openAppRating"]) {
        if (@available(iOS 10.3, *)) {
            [SKStoreReviewController requestReview];
        } else {
            [self reject:[NSError
                          errorWithDomain:kInAppMessagingDisplayErrorDomain
                          code:IAMDisplayRenderErrorTypeUnspecifiedError
                          userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Method not available on iOS < 10.3", nil)}]
                  callId:callId];
        }
    }
    else if ([methodName isEqual:@"trackEvent"]) {
        NSString *eventName = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        NSDictionary *attributes = args.count >= 2 && [args[1] isKindOfClass:NSDictionary.class] ? args[1] : nil;
        if (eventName) {
            [self.webView.controllerDelegate trackEvent:eventName attributes:attributes];
            [self resolve:nil callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"trackEvent requires an event name", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"addTag"]) {
        // Support array as first arg
        NSArray *tags = [args.firstObject isKindOfClass:NSArray.class] ? args.firstObject : args;
        // Filter on strings only
        tags = [tags filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^(id obj, NSDictionary *bindings) { return [obj isKindOfClass:NSString.class]; }]];
        [WonderPush addTags:tags];
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqual:@"removeTag"]) {
        // Support array as first arg
        NSArray *tags = [args.firstObject isKindOfClass:NSArray.class] ? args.firstObject : args;
        // Filter on strings only
        tags = [tags filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^(id obj, NSDictionary *bindings) { return [obj isKindOfClass:NSString.class]; }]];
        [WonderPush removeTags:tags];
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqual:@"removeAllTags"]) {
        [WonderPush removeAllTags];
        [self resolve:nil callId:callId];
    }
    else if ([methodName isEqual:@"hasTag"]) {
        NSString *tag = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        if (tag) {
            [self resolve:[WPIAMBoolResult with:[WonderPush hasTag:tag]] callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"hasTag requires a tag argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"getTags"]) {
        NSOrderedSet<NSString *> *tags = [WonderPush getTags];
        [self resolve:[NSArray arrayWithArray:tags.array] callId:callId];
    }
    else if ([methodName isEqual:@"getPropertyValue"]) {
        NSString *property = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        if (property) {
            [self resolve:[WonderPush getPropertyValue:property] callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"getPropertyValue requires a string argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"getPropertyValues"]) {
        NSString *property = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        if (property) {
            [self resolve:[WonderPush getPropertyValues:property] callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"getPropertyValues requires a string argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"addProperty"]) {
        NSString *property = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        id val = args.count >= 2 ? args[1] : nil;
        if (property && val) {
            [WonderPush addProperty:property value:val];
            [self resolve:nil callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"addProperty requires a string argument and a value argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"removeProperty"]) {
        NSString *property = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        id val = args.count >= 2 ? args[1] : nil;
        if (property) {
            [WonderPush removeProperty:property value:val];
            [self resolve:nil callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"removeProperty requires a string argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"setProperty"]) {
        NSString *property = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        id val = args.count >= 2 ? args[1] : nil;
        if (property && args.count >= 2) {
            [WonderPush setProperty:property value:val];
            [self resolve:nil callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"setProperty requires a string argument and a value argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"unsetProperty"]) {
        NSString *property = args.count >= 1 && [args[0] isKindOfClass:NSString.class] ? args[0] : nil;
        if (property) {
            [WonderPush unsetProperty:property];
            [self resolve:nil callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"unsetProperty requires a string argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"putProperties"]) {
        NSDictionary *properties = args.count >= 1 && [args[0] isKindOfClass:NSDictionary.class] ? args[0] : nil;
        if (properties) {
            [WonderPush putProperties:properties];
            [self resolve:nil callId:callId];
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"putProperties requires an object argument", nil),
            }] callId:callId];
        }
    }
    else if ([methodName isEqual:@"getProperties"]) {
        [self resolve:[WonderPush getProperties] callId:callId];
    }
}

- (void) getPayload:(NSString *)callId {
    [self resolve:self.webView.inAppMessage.payload callId:callId];
}
- (void) openDeepLink:(NSArray *)args callId:(NSString *)callId {
    if (args.count < 1 || ![args[0] isKindOfClass:NSString.class]) {
        [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Url is mandatory", nil),
        }] callId:callId];
        return;
    }
    NSString *urlString = args[0];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid url", nil),
        }] callId:callId];
        return;
    }
    [WPURLFollower.URLFollower
     followURL:url
     withCompletionBlock:^(BOOL success) {
        WPLogDebug(@"Successfully opened %@", url);
        if (success) {
            [self resolve:nil callId:callId];
            if (self.webView.onDismiss) {
                self.webView.onDismiss(WPInAppMessagingDismissTypeUserTapClose);
            }
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Could not open URL", nil),
            }] callId:callId];
        }
    }];
}

- (void) openExternalUrl:(NSArray *)args callId:(NSString *)callId {
    if (args.count < 1 || ![args[0] isKindOfClass:NSString.class]) {
        [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Url is mandatory", nil),
        }] callId:callId];
        return;
    }
    NSString *urlString = args[0];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid url", nil),
        }] callId:callId];
        return;
    }
    [WPURLFollower.URLFollower
     followURLViaIOS:url
     withCompletionBlock:^(BOOL success) {
        WPLogDebug(@"Successfully opened %@", url);
        if (success) {
            [self resolve:nil callId:callId];
            if (self.webView.onDismiss) {
                self.webView.onDismiss(WPInAppMessagingDismissTypeUserTapClose);
            }
        } else {
            [self reject:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain code:IAMDisplayRenderErrorTypeUnspecifiedError userInfo:@{
                NSLocalizedDescriptionKey: NSLocalizedString(@"Could not open URL", nil),
            }] callId:callId];
        }
    }];
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (navigationAction.targetFrame.isMainFrame) {
        return nil;
    }
    [self openExternalUrl:@[navigationAction.request.URL.absoluteString] callId:nil];
    return nil;
}

@end

@implementation WPIAMWebViewNavigationDelegate

- (void)reportFailWithError:(NSError *)error {
    if (!self.webViewUrlLoadingCallbackDone) {
        self.webViewUrlLoadingCallbackDone = YES;
        if (self.webView.onNavigationError) {
            self.webView.onNavigationError(error);
        }
    }
}

- (void)reportSuccess {
    if (!self.webViewUrlLoadingCallbackDone) {
        self.webViewUrlLoadingCallbackDone = YES;
        if (self.webView.onNavigationSuccess) {
            self.webView.onNavigationSuccess(self.webView);
        }
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (!self.webViewUrlLoadingCallbackDone) {
        //webview timeout of X seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, INAPP_WEBVIEW_LOAD_TIMEOUT_TIME_INTERVAL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeTimeoutError
                                             userInfo:@{NSLocalizedDescriptionKey: @"Timeout exception occured to load webView url"}];
            [self reportFailWithError:error];
        });
    }
}


- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    NSURL *initialURL = self.webView.initialURL;
    NSURL *targetURL = webView.URL;

    // Ensure same origin
    if (initialURL.port == targetURL.port
        && [initialURL.host isEqualToString:targetURL.host]
        && [initialURL.scheme isEqualToString:targetURL.scheme]) {
        // Inject message handler
        [self.webView.configuration.userContentController addScriptMessageHandler:self.webView.bridge name:INAPP_SDK_GLOBAL_NAME];
        // Inject bridge
        NSString *javascriptToInjectFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"webViewBridgeJavascriptFileToInject" ofType:@"js"];
        NSString* javascriptString = [NSString stringWithContentsOfFile:javascriptToInjectFile encoding:NSUTF8StringEncoding error:nil];
        [webView evaluateJavaScript:javascriptString completionHandler:nil];
    } else {
        // Remove message handler
        [self.webView.configuration.userContentController removeScriptMessageHandlerForName:INAPP_SDK_GLOBAL_NAME];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {

    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {

        NSHTTPURLResponse * response = (NSHTTPURLResponse *)navigationResponse.response;
        if (response.statusCode >= 400) {
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeHTTPError
                                             userInfo:@{NSLocalizedDescriptionKey: @"Bad response code"}];
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
                                     userInfo:@{NSLocalizedDescriptionKey: @"Page load terminated"}];
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction didBecomeDownload:(WKDownload *)download API_AVAILABLE(ios(14.5)) {
    [download cancel:^(NSData *data) {}];
    NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                         code:IAMDisplayRenderErrorTypeNavigationBecameDownloadError
                                     userInfo:@{NSLocalizedDescriptionKey: @"Navigation became download"}];
    [self reportFailWithError:error];
}

- (void)webView:(WKWebView *)webView navigationResponse:(WKNavigationResponse *)navigationResponse didBecomeDownload:(WKDownload *)download API_AVAILABLE(ios(14.5)) {
    [download cancel:^(NSData *data) {}];
    NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                         code:IAMDisplayRenderErrorTypeNavigationBecameDownloadError
                                     userInfo:@{NSLocalizedDescriptionKey: @"Navigation became download"}];
    [self reportFailWithError:error];
}

@end
