//
//  AppDelegate.m
//  WonderPushExample
//
//  Created by Stéphane JAIS on 12/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "AppDelegate.h"
#import <WonderPush/WonderPush.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    NSLog(@"toto application:didFinishLaunchingWithOptions:%@", launchOptions);

#ifdef DEBUG
    [WonderPush setLogging:YES];
#endif

    // Replace with real values
    [WonderPush setClientId:@"47d9054ece4faca1882ba05abcf60163941597f4" secret:@"f7864cc6cffc9eea85f1dac4788978434f5325e06cdfe32c1b3139b3d5c18f30"];
    
    [WonderPush setupDelegateForApplication:application];
    [WonderPush setupDelegateForUserNotificationCenter];
    [WonderPush subscribeToNotifications];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"toto application:openURL:options: %@", url);
    return true;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    NSURL *url = userActivity.webpageURL;
    NSLog(@"toto application:continueUserActivity:%@ url:%@", userActivity, url);
    if (![userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) return NO;
    return YES;
}
@end
