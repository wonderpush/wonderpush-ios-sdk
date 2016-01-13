//
//  WPAppDelegate.m
//  WonderPush
//
//  Created by Olivier Favre on 13/01/16.
//  Copyright © 2016 WonderPush. All rights reserved.
//

#import "WPAppDelegate.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "WonderPush.h"


const char * const WPAPPDELEGATE_ASSOCIATION_KEY = "com.wonderpush.sdk.WPAppDelegate";


@interface WPAppDelegate ()

@end


@implementation WPAppDelegate

@synthesize nextDelegate;


#pragma mark - Setup and chaining

+ (void) setupDelegateForApplication:(UIApplication *)application
{
    WPAppDelegate *delegate = [WPAppDelegate new];

    // Make sure to provide the same window
    if ([application.delegate respondsToSelector:@selector(window)]) {
        delegate.window = application.delegate.window;
    }

    // Retain the delegate as long as the UIApplication lives
    objc_setAssociatedObject(application, WPAPPDELEGATE_ASSOCIATION_KEY, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Note: the association is not breakable, like the created delegate chain

    // Setup the delegate chain
    delegate.nextDelegate = application.delegate;
    application.delegate = delegate;
}

- (id) forwardingTargetForSelector:(SEL)aSelector
{
    NSLog(@"forwardingTargetForSelector:%@ -> %@", NSStringFromSelector(aSelector), self.nextDelegate);
    return self.nextDelegate;
}


#pragma mark - Overriding useful methods

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [WonderPush handleApplicationLaunchWithOption:launchOptions];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        return [self.nextDelegate application:application didFinishLaunchingWithOptions:launchOptions];
    } else {
        return YES;
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    [WonderPush handleNotification:notification.userInfo];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didReceiveLocalNotification:notification];
    }
}

-(void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [WonderPush didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [WonderPush didFailToRegisterForRemoteNotificationsWithError:error];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didFailToRegisterForRemoteNotificationsWithError:error];
    }
}

-(void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [WonderPush handleDidReceiveRemoteNotification:userInfo];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didReceiveRemoteNotification:userInfo];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [WonderPush applicationDidEnterBackground:application];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate applicationDidEnterBackground:application];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [WonderPush applicationDidBecomeActive:application];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate applicationDidBecomeActive:application];
    }
}


@end