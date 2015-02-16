WonderPush iOS SDK Guide
------------------------


# <a id="register-app-wonderpush"></a>1. Register your application in WonderPush

Log in or sign up on [WonderPush](http://www.wonderpush.com).

Create your application.
Make sure to check `iOS` under the `Platforms` section.

Grab your *client id* and *client secret* under ther `Settings / Keys` menu.


# <a id="download-sdk"></a>2. Download the latest WonderPush SDK for iOS

Download the latest release [on GitHub](https://github.com/wonderpush/wonderpush-ios-sdk/releases/latest).


# <a id="setup-project"></a>3. Setup your project

- Extract `WonderPush.framework` from the downloaded archive.
- Drag and drop the `WonderPush.framework` file to your project.
- Select your project file in the project navigator.
- On the top right side select `General`.
- Scroll down to `Linked Frameworks and libraries` and click on the plus to add the following frameworks:

    - SystemConfiguration
    - MobileCoreServices
    - CoreGraphics
    - UIKit
    - CoreTelephony
    - CoreLocation
    - CoreBluetooth
    - AVFoundation
    - CoreMotion


# <a id="initialize-sdk"></a>4. Initialize the SDK

Add this code to the corresponding method of you Application delegate:

    #import <WonderPush/WonderPush.h>

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        [WonderPush setClientId:@"[YOUR_CLIENT_ID]" secret:@"[YOUR_CLIENT_SECRET]"];
        [WonderPush setNotificationEnabled:YES];
        [WonderPush handleApplicationLaunchWithOption:launchOptions];
        return YES;
    }

    - (void)applicationDidEnterBackground:(UIApplication *)application {
        [WonderPush applicationDidEnterBackground:application];
    }

    - (void)applicationDidBecomeActive:(UIApplication *)application {
        [WonderPush applicationDidBecomeActive:application];
    }

Replace:

- **[YOUR_CLIENT_ID]** with your client id found in your [WonderPush dashboard](https://dashboard.wonderpush.com/), under the `Settings / Keys` menu.
  Eg.: 0123456789abcdef0123456789abcdef01234567.
- **[YOUR_CLIENT_ID]** with your client secret found in your [WonderPush dashboard](https://dashboard.wonderpush.com/), next to the client id as described above.
  Eg.: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.


# <a id="remote-notifications"></a>5. Handle remote notifications

First of all you have to set up your application as described in the [Configuring Push Notifications guide](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/ConfiguringPushNotifications/ConfiguringPushNotifications.html#//apple_ref/doc/uid/TP40012582-CH32-SW1).

Once you created your provisioning profile associated to a certificate on your computer you will have to export your push notifications certificate
in order to let WonderPush to send notification to your device:

- Launch `KeyChain Access`
- Select the newly created certificate associated to your appId.  
  Its name should be `Apple Development/Production iOS Push Services: [your.app.id]`  
  _If you don't see it_, make sure you have downloaded the iOS Push Service certificate Apple generated for your application:
  - Log into the [member center](https://developer.apple.com/account/ios/certificate/certificateList.action) and choose `Certificates, Identifiers & Profiles` section.
  - Under `Certificates`, click the certificate corresponding to your appId, of type either `APNs Development iOS` or `APNs Production iOS`.  
    The development certificate is used for sending to the devices you develop with. The production certificate is used for applications distributed through the App Store or TestFlight.
  - Click `Download`, and open the certificate with `Keychain Access`.
- Make sure you see a matching private key when you expand the certificate item, but select only the certificate.
- Click on `File / Export items`.
- Do not enter any password.
- Open a command line and go to the directory where you exported the certificate.
- Type the following command to generate the `.pem` file:

      openssl pkcs12 -nodes -clcerts -out [name].pem -in [previously explorted file].p12

- Again, type no password when prompted.

Then go to your [WonderPush dashboard](https://dashboard.wonderpush.com/) and upload the certificate in the `Settings / Keys` page of your application management

In order to handle push notifications, you will have to modify your Application delegate so that all notifications will be forwarded to the WonderPush SDK.
Add the following methods:

    -(void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
    {
        [WonderPush didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }

    -(void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    {
        [WonderPush handleDidReceiveRemoteNotification:userInfo];
    }

    // You may appreciate the following during development :-)
    - (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
    {
        NSLog(@"Error: %@", error);
    }

That's it you should now be able to receive push notifications from WonderPush.


# <a id="background-mode"></a>6. Handling background mode

*Note:* If your application does not use the Remote notifications Background mode, you can safely skip this step.  
If in doubt, click your project in the project navigator, select a target, go to the `Capabilities` tab, and under `Background modes`, see whether `Remote notifications` is checked.

If your applications uses the Remote notification Background mode, the behaviour of the notification is not exactly the same.
In order to make WonderPush work in this case, overload the following method in your application delegate as follows:

    - (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
    {
        [WonderPush handleNotification:notification.userInfo];
    }

Your application now correctly receives push notifications.


# <a id="using-sdk"></a>7. Using the SDK in your iOS application

### <a id="using-sdk--track-event"></a>Track your first event

The SDK automatically tracks genetic events. This is probably insufficient to help you analyze, segment and notify users properly.
You will want to track events that make sense for your business, here is an simple example:

    [WonderPush trackEvent:"customized_interests" withData:nil];

This would permit you to know easily whether a user kept the default set of "topics of interests", say in a newsstand application, or if they already chose a topics that represents well their center of interest.

Your notification strategy could be to incite to customization for the lazy users, whereas you could engage in a more personalized communication with the users you performed the `customized_interests` event.

### <a id="using-sdk--track-event-custom"></a>Enriching the events

Events can host a rich set of properties that WonderPush indexes to permit you to filter users based on finer criteria.
To do so, simply give a JSON object as second parameter. Here is an example:

    [WonderPush trackEvent:"browse_catalog" withData:@{"string_category": @"fashion"}];

Using this information, you could notify customers on new items for the categories that matters most to them.

Here is another example:

    [WonderPush trackEvent:"purchase" withData:@{@"int_foo": [NSNumber numberWithInt:3], @"float_amount": [NSNumber numberWithFloat:59.98]}];

You could choose to thank customer for every purchase, or you could take advantage of the purchase amount to give differentiated coupons to best buyers.

### <a id="using-sdk--installation-properties"></a>Tagging users

Some information are better represented as properties on a user, rather than discrete events in a timeline.
Here is an example:

    - (void)didAddItemToCart:(NSString*)item withPrice:(double)price
    {
        // Variables managed by your application
        cartItems += 1;
        cartAmount += price;
        // ...

        // Update this information in WonderPush
        [WonderPush putInstallationCustomProperties:@{@"int_itemsInCart": [NSNumber numberWithInt:cartItems],
                                                      @"float_cartAmount": [NSNumber numberWithFloat:cartAmount]}];
    }

    - (void)didPurchase {
        // Empty the information in WonderPush
        [WonderPush putInstallationCustomProperties:@{@"int_itemsInCart": [NSNull null],
                                                      @"float_cartAmount": [NSNull null]}];
    }

Inactive users with non-empty carts could then easily be notified. Combined with a free delivery coupon for carts above a given amount, your conversion rate will improve still!

### <a id="advanced--reading-custom-key-value-payload"></a>Reading custom key-value payload

A notification can be added custom key-value pairs to it.
In order to retrieve them, simply add one line of code in the appropriate methods of your application delegate as follow:

    - (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    {
        [WonderPush handleDidReceiveRemoteNotification:userInfo];
        // Get the custom payload
        NSDictionary * custom = [userInfo objectForKey:@"custom"];
    }

    // If you use the remote-notification background mode
    - (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
    {
        [WonderPush handleNotification:notification.userInfo];
        // Get the custom payload
        NSDictionary * custom = [notification.userInfo objectForKey:@"custom"];
    }



<a id="demo-app"></a>Demo application
----------------

You can read an example integration by looking at the code of our [Demo Application, available on GitHub](https://github.com/wonderpush/wonderpush-ios-demo).



<a id="reference"></a>API Reference
-------------

Take a look at the methods exposed by the <WonderPush> class.
