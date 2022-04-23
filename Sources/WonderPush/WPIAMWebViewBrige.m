//
//  WPIAMWebViewBrige.m
//  WonderPush
//
//  Created by Prouha Kévin on 09/04/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

#import "WPIAMWebViewBrige.h"
#import "WonderPush.h"

@implementation WPIAMWebViewBrige

-(void) onWPIAMWebViewDidReceivedMessage: (NSDictionary *) receivedMessageFromBridge with : (NSString *) methodName in: (WKWebView *) wkWebViewInstance {
    
    if ([methodName  isEqual: @"openTargetUrl"]){
        [wkWebViewInstance evaluateJavaScript:@"window._iosResults.resolve();" completionHandler:nil];
    }
    
    /*if ([methodName  isEqual: @"openTargetUrl"]){
        [self openTargetUrlFor:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"subscribeToNotifications"]){
        [self subscribeToNotificationsAndSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"unsubscribeFromNotifications"]){
        [self unSubscribeToNotificationsAndSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"isSubscribedToNotifications"]){
        [self sendIsSubscribedToNotificationsCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getUserId"]){
        [self sendUserIdCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getInstallationId"]){
        [self sendInstallationIdCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getCountry"]){
        [self sendCountryCallbackTo:wkWebViewInstance];
    }
    else if ([methodName isEqual: @"getCurrency"]){
        [self sendCurrencyCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getLocale"]){
        [self sendLocaleCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getTimeZone"]){
        [self sendTimezoneCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"trackEvent"]){
        [self trackEventFor:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"addTag"]){
        [self addTagFor:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"removeTag"]){
        [self removeTagFor:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"removeAllTags"]){
        [self removeAllTagsAndSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"hasTag"]){
        [self checkIfHasTag:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getTags"]){
        [self sendTagsCallbackTo:wkWebViewInstance];
    }
    else if ([methodName isEqual: @"getPropertyValue"]){
        [self getPropertyValue:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getPropertyValues"]){
        [self getPropertyValues:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"addProperty"]){
        [self addProperty:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"removeProperty"]){
        [self removeProperty:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"setProperty"]){
        [self setProperty:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"unsetProperty"]){
        [self unsetProperty:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"putProperties"]){
        [self putProperties:receivedMessageFromBridge andSendCallbackTo:wkWebViewInstance];
    }
    else if ([methodName  isEqual: @"getProperties"]){
        [self sendPropertiesCallbackTo:wkWebViewInstance];
    }*/
}

/********************************************************************/
/*                       OPEN TARGET URL                            */

- (void) openTargetUrlFor : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
            
        if (nil == [receivedMessageFromBridge valueForKey:@"url"]){
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['openTargetUrl'].reject();" completionHandler:nil];
            return;
        }
        
        if (nil != [receivedMessageFromBridge valueForKey:@"mode"]){
            NSString * modeWantedByUser = [receivedMessageFromBridge valueForKey:@"mode"];
            
            if ([modeWantedByUser isEqualToString:@"external"] || [modeWantedByUser isEqualToString:@"parent"]){
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[receivedMessageFromBridge valueForKey:@"url"]]];
            }
            else {
                NSURL *nsUrlInstanceToLoad = [NSURL URLWithString:[receivedMessageFromBridge valueForKey:@"url"]];
                NSURLRequest *nsUrlRequestInstanceToLoad = [NSURLRequest requestWithURL:nsUrlInstanceToLoad];
                [wkWebViewInstance loadRequest: nsUrlRequestInstanceToLoad];
            }
        }
        else
        {
            NSURL *nsUrlInstanceToLoad = [NSURL URLWithString:[receivedMessageFromBridge valueForKey:@"url"]];
            NSURLRequest *nsUrlRequestInstanceToLoad = [NSURLRequest requestWithURL:nsUrlInstanceToLoad];
            [wkWebViewInstance loadRequest: nsUrlRequestInstanceToLoad];
        }
        
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['openTargetUrl'].resolve();" completionHandler:nil];
        return;
}

/********************************************************************/
/*                       SUBSCRIBE TO NOTIFICATIONS                 */

- (void) subscribeToNotificationsAndSendCallbackTo : (WKWebView *) wkWebViewInstance{

    [WonderPush subscribeToNotifications];
    [wkWebViewInstance evaluateJavaScript:@"window._wpresults['subscribeToNotifications'].resolve();" completionHandler:nil];
}

/********************************************************************/
/*                       UNSUBSCRIBE TO NOTIFICATIONS               */

- (void) unSubscribeToNotificationsAndSendCallbackTo : (WKWebView *) wkWebViewInstance{

    [WonderPush unsubscribeFromNotifications];
    [wkWebViewInstance evaluateJavaScript:@"window._wpresults['unsubscribeFromNotifications'].resolve();" completionHandler:nil];
}

/********************************************************************/
/*                     IS SUBSCRIBED TO NOTIFICATIONS               */

- (void) sendIsSubscribedToNotificationsCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['isSubscribedToNotifications'].resolve(%s);", [WonderPush isSubscribedToNotifications] ? "true" : "false"];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                          GET USER ID                             */

- (void) sendUserIdCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getUserId'].resolve('%@');", [WonderPush userId]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                          GET INSTALLATION ID                     */

- (void) sendInstallationIdCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getInstallationId'].resolve('%@');", [WonderPush installationId]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                          GET COUNTRY                             */

- (void) sendCountryCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getCountry'].resolve('%@');", [WonderPush country]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                          GET CURRENCY                             */

- (void) sendCurrencyCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getCurrency'].resolve('%@');", [WonderPush currency]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                          GET LOCALE                              */

- (void) sendLocaleCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getLocale'].resolve('%@');", [WonderPush locale]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                          GET TIMEZONE                            */

- (void) sendTimezoneCallbackTo : (WKWebView *) wkWebViewInstance{
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getTimeZone'].resolve('%@');", [WonderPush timeZone]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                         TRACK EVENT                              */
- (void) trackEventFor : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{

        if([receivedMessageFromBridge[@"event"] isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dictionnaryParamsFromWeb = receivedMessageFromBridge[@"event"];
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"type"]){
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['trackEvent'].reject();" completionHandler:nil];
                return;
            }
            
            if (nil != [dictionnaryParamsFromWeb valueForKey:@"attributes"]){
                [WonderPush trackEvent:[dictionnaryParamsFromWeb valueForKey:@"type"] attributes:[dictionnaryParamsFromWeb valueForKey:@"attributes"]];
            }
            else
            {
                [WonderPush trackEvent:[dictionnaryParamsFromWeb valueForKey:@"type"]];
            }
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['trackEvent'].reject();" completionHandler:nil];
            return;
        }
        
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['trackEvent'].resolve();" completionHandler:nil];
        return;
}

/********************************************************************/
/*                         ADD TAG                                  */

- (void) addTagFor : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([(NSDictionary *) receivedMessageFromBridge[@"tag"] isKindOfClass:[NSArray class]])
        {
            NSArray *tagsToAdd = receivedMessageFromBridge[@"tag"];
            [WonderPush addTags:tagsToAdd];
            
        }
        else if ([receivedMessageFromBridge[@"tag"] isKindOfClass:[NSString class]]){
            NSString * tagToAdd = receivedMessageFromBridge[@"tag"];
            [WonderPush addTag:tagToAdd];
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addTag'].reject();" completionHandler:nil];
            return;
        }
        
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addTag'].resolve();" completionHandler:nil];
        return;
}

/********************************************************************/
/*                         REMOVE TAG                               */

- (void) removeTagFor : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"tag"] isKindOfClass:[NSArray class]])
        {
            NSArray *tagsToRemove = receivedMessageFromBridge[@"tag"];
            [WonderPush removeTags:tagsToRemove];
            
        }
        else if ([receivedMessageFromBridge[@"tag"] isKindOfClass:[NSString class]]){
            NSString * tagToRemove = receivedMessageFromBridge[@"tag"];
            [WonderPush removeTag:tagToRemove];
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeTag'].reject();" completionHandler:nil];
            return;
        }
        
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeTag'].resolve();" completionHandler:nil];
        return;
}

/********************************************************************/
/*                         REMOVE ALL TAGS                          */

- (void) removeAllTagsAndSendCallbackTo : (WKWebView *) wkWebViewInstance{

    [WonderPush removeAllTags];
    [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeAllTags'].resolve();" completionHandler:nil];
}

/********************************************************************/
/*                           HAS TAG                                */

- (void) checkIfHasTag : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"tag"] isKindOfClass:[NSString class]])
        {
            NSString *tagToCheck = receivedMessageFromBridge[@"tag"];
            NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['hasTag'].resolve(%s);", [WonderPush hasTag:tagToCheck] ? "true" : "false"];
            [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
            return;
            
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['hasTag'].reject();" completionHandler:nil];
            return;
        }
}

/********************************************************************/
/*                           GET TAGS                               */

- (void) sendTagsCallbackTo : (WKWebView *) wkWebViewInstance{
    NSError* jsonEncodingError = nil;
    NSData *tagsJsonData = [NSJSONSerialization dataWithJSONObject:[WonderPush getTags].array options:NSJSONWritingPrettyPrinted error:&jsonEncodingError];
    if (jsonEncodingError != nil){
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['getTags'].reject();" completionHandler:nil];
        return;
    }
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getTags'].resolve(%@);", [[NSString alloc] initWithData:tagsJsonData encoding:NSUTF8StringEncoding]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

/********************************************************************/
/*                           GET PROPERTY VALUE                     */

- (void) getPropertyValue : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"property"] isKindOfClass:[NSString class]])
        {
            NSString *propertyValueToGet = receivedMessageFromBridge[@"property"];
            NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getPropertyValue'].resolve('%@');", [WonderPush getPropertyValue:propertyValueToGet]];
            [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
            return;
            
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['getPropertyValue'].reject();" completionHandler:nil];
            return;
        }
}

/********************************************************************/
/*                           GET PROPERTY VALUES                    */

- (void) getPropertyValues : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{

    if([receivedMessageFromBridge[@"property"] isKindOfClass:[NSString class]])
    {
        NSString *propertyValuesToGet = receivedMessageFromBridge[@"property"];
        NSError* jsonEncodingError = nil;
        NSData *propertyValuesJsonData = [NSJSONSerialization dataWithJSONObject:[WonderPush getPropertyValues:propertyValuesToGet] options:NSJSONWritingPrettyPrinted error:&jsonEncodingError];
        if (jsonEncodingError != nil){
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['getPropertyValues'].reject();" completionHandler:nil];
            return;
        }
        NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getPropertyValues'].resolve(%@);", [[NSString alloc] initWithData:propertyValuesJsonData encoding:NSUTF8StringEncoding]];
        [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
        return;
        
    }
    else {
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['getPropertyValues'].reject();" completionHandler:nil];
        return;
    }
}

/********************************************************************/
/*                           ADD PROPERTY VALUE                     */

- (void) addProperty : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"property"] isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dictionnaryParamsFromWeb = receivedMessageFromBridge[@"property"];
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"field"]){
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addProperty'].reject();" completionHandler:nil];
                return;
            }
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"value"]){
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addProperty'].reject();" completionHandler:nil];
                return;
            }
            
            if([ [dictionnaryParamsFromWeb valueForKey:@"value"] isKindOfClass:[NSArray class]])
            {
                [WonderPush addProperty:[dictionnaryParamsFromWeb valueForKey:@"field"] value: [dictionnaryParamsFromWeb valueForKey:@"value"]];
            }
            else if ([ [dictionnaryParamsFromWeb valueForKey:@"value"] isKindOfClass:[NSString class]]){
                [WonderPush addProperty:[dictionnaryParamsFromWeb valueForKey:@"field"] value: [dictionnaryParamsFromWeb valueForKey:@"value"]];
            }
            else {
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addProperty'].reject();" completionHandler:nil];
                return;
            }
            
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addProperty'].resolve();" completionHandler:nil];
            return;
            
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['addProperty'].reject();" completionHandler:nil];
            return;
        }
}

/********************************************************************/
/*                           REMOVE PROPERTY VALUE                  */

- (void) removeProperty : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"property"] isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dictionnaryParamsFromWeb = receivedMessageFromBridge[@"property"];
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"field"]){
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeProperty'].reject();" completionHandler:nil];
                return;
            }
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"value"]){
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeProperty'].reject();" completionHandler:nil];
                return;
            }
            
            if([ [dictionnaryParamsFromWeb valueForKey:@"value"] isKindOfClass:[NSArray class]])
            {
                [WonderPush removeProperty:[dictionnaryParamsFromWeb valueForKey:@"field"] value: [dictionnaryParamsFromWeb valueForKey:@"value"]];
            }
            else if ([ [dictionnaryParamsFromWeb valueForKey:@"value"] isKindOfClass:[NSString class]]){
                [WonderPush removeProperty:[dictionnaryParamsFromWeb valueForKey:@"field"] value: [dictionnaryParamsFromWeb valueForKey:@"value"]];
            }
            else {
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeProperty'].reject();" completionHandler:nil];
                return;
            }
            
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeProperty'].resolve();" completionHandler:nil];
            return;
            
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['removeProperty'].reject();" completionHandler:nil];
            return;
        }
}

/********************************************************************/
/*                           SET PROPERTY                           */

- (void) setProperty : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"property"] isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dictionnaryParamsFromWeb = receivedMessageFromBridge[@"property"];
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"field"]){
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['setProperty'].reject();" completionHandler:nil];
                return;
            }
            
            if (nil == [dictionnaryParamsFromWeb valueForKey:@"value"]){
                [WonderPush unsetProperty:dictionnaryParamsFromWeb[@"field"]];
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['setProperty'].resolve();" completionHandler:nil];
                return;
            }
            
            if ([[dictionnaryParamsFromWeb valueForKey:@"value"] isEqual:nil] || [[dictionnaryParamsFromWeb valueForKey:@"value"] isEqual:@"undefined"]){
                [WonderPush unsetProperty:dictionnaryParamsFromWeb[@"field"]];
                [wkWebViewInstance evaluateJavaScript:@"window._wpresults['setProperty'].resolve();" completionHandler:nil];
                return;
            }
            
            [WonderPush setProperty:[dictionnaryParamsFromWeb valueForKey:@"field"] value:[dictionnaryParamsFromWeb valueForKey:@"value"]];
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['setProperty'].resolve();" completionHandler:nil];
            return;
            
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['setProperty'].reject();" completionHandler:nil];
            return;
        }
}

/********************************************************************/
/*                           UNSET PROPERTY                         */

- (void) unsetProperty : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
        if([receivedMessageFromBridge[@"property"] isKindOfClass:[NSString class]])
        {
            [WonderPush unsetProperty:receivedMessageFromBridge[@"property"]];
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['unsetProperty'].resolve();" completionHandler:nil];
            return;
            
        }
        else {
            [wkWebViewInstance evaluateJavaScript:@"window._wpresults['unsetProperty'].reject();" completionHandler:nil];
            return;
        }
}

/********************************************************************/
/*                          PUT PROPERTIES                          */

- (void) putProperties : (NSDictionary *) receivedMessageFromBridge andSendCallbackTo : (WKWebView *) wkWebViewInstance{
        
    if([receivedMessageFromBridge[@"properties"] isKindOfClass:[NSDictionary class]])
    {
        [WonderPush putProperties:receivedMessageFromBridge[@"properties"]];
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['putProperties'].resolve();" completionHandler:nil];
        return;
        
    }
    else {
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['putProperties'].reject();" completionHandler:nil];
        return;
    }
}

/********************************************************************/
/*                          GET PROPERTIES                          */

- (void) sendPropertiesCallbackTo : (WKWebView *) wkWebViewInstance{
    NSError* jsonEncodingError = nil;
    NSData *propertiesJsonData = [NSJSONSerialization dataWithJSONObject:[WonderPush getProperties] options:NSJSONWritingPrettyPrinted error:&jsonEncodingError];
    if (jsonEncodingError != nil){
        [wkWebViewInstance evaluateJavaScript:@"window._wpresults['getProperties'].reject();" completionHandler:nil];
        return;
    }
    NSString * javascriptToEvaluate = [NSString stringWithFormat:@"window._wpresults['getProperties'].resolve(%@);", [[NSString alloc] initWithData:propertiesJsonData encoding:NSUTF8StringEncoding]];
    [wkWebViewInstance evaluateJavaScript:javascriptToEvaluate completionHandler:nil];
}

@end
