//
//  WonderPush_constants.h
//  WonderPush
//
//  Created by Stéphane JAIS on 12/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#ifndef WonderPush_constants_h
#define WonderPush_constants_h

#define SDK_VERSION @"iOS-4.0.11"
#define PRODUCTION_API_DOMAIN @"api.wonderpush.com"
#define PRODUCTION_API_URL @"https://" PRODUCTION_API_DOMAIN @"/v1/"
#define REMOTE_CONFIG_BASE_URL @"https://cdn.by.wonderpush.com/config/clientids/"
#define REMOTE_CONFIG_SUFFIX @"-iOS"

#define RETRY_INTERVAL 10.0f
#define CACHED_INSTALLATION_CUSTOM_PROPERTIES_MIN_DELAY 5
#define CACHED_INSTALLATION_CUSTOM_PROPERTIES_MAX_DELAY 20
#define CACHED_INSTALLATION_CORE_PROPERTIES_MIN_DELAY 5
#define CACHED_INSTALLATION_CORE_PROPERTIES_MAX_DELAY 20

#define ITUNES_APP_URL_FORMAT @"https://itunes.apple.com/us/app/calcfast/id%@?mt=8"
#define WEB_CALLBACK_RESOURCE @"web/callback"

#define DIFFERENT_SESSION_REGULAR_MIN_TIME_GAP      (30*60*1000)
#define DIFFERENT_SESSION_NOTIFICATION_MIN_TIME_GAP (15*60*1000)

#define PRESENCE_UPDATE_SAFETY_MARGIN 60
#define PRESENCE_ANTICIPATED_TIME (5*60)

/**
 Key to set in your .plist file to allow rating button action
 */
#define WP_ITUNES_APP_ID @"itunesAppID"


/**
 Key of the WonderPush content in a push notification
 */
#define WP_PUSH_NOTIFICATION_KEY @"_wp"

/**
 Key of the notification type in the WonderPush content of a push notification
 */
#define WP_PUSH_NOTIFICATION_TYPE_KEY @"type"

/**
 Key of the deep link url to open with the notification
 */
#define WP_TARGET_URL_KEY @"targetUrl"

/**
 Key of the targetUrlMode
 */
#define WP_TARGET_URL_MODE_KEY @"targetUrlMode"

/**
 Notification of type url
 */
#define WP_PUSH_NOTIFICATION_SHOW_URL @"url"

/**
 Notification of type text
 */
#define WP_PUSH_NOTIFICATION_SHOW_TEXT @"text"

/**
 Notification of type html
 */
#define WP_PUSH_NOTIFICATION_SHOW_HTML @"html"

/**
 Notification of type data
 */
#define WP_PUSH_NOTIFICATION_DATA @"data"

#define DEFAULT_LAST_RECEIVED_NOTIFICATION_CHECK_DELAY 7 * 86400

#define LAST_RECEIVED_NOTIFICATION_CHECK_DATE_USER_DEFAULTS_KEY @"_wonderpush_lastReceivedNotificationCheckDate"
#define LAST_RECEIVED_NOTIFICATION_CHECK_DATE_PROPERTY @"lastReceivedNotificationCheckDate"
#endif /* WonderPush_constants_h */
