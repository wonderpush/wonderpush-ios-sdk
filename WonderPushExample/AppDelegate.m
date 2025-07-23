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
    
#ifdef DEBUG
    [WonderPush setLogging:YES];
#endif

    // Replace with real values
    [WonderPush setClientId:@"USE_REMEMBERED" secret:@"USE_REMEMBERED"];
    
    [WonderPush setupDelegateForApplication:application];
    [WonderPush setupDelegateForUserNotificationCenter];
    [WonderPush subscribeToNotifications];
    return YES;
}

@end
