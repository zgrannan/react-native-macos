/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <React/RCTEventEmitter.h>

extern NSString *const RCTRemoteNotificationReceived;

@interface RCTPushNotificationManager : RCTEventEmitter

#if !TARGET_OS_OSX
typedef void (^RCTRemoteNotificationCallback)(UIBackgroundFetchResult result);
#endif

#if !TARGET_OS_TV
#if !TARGET_OS_OSX
+ (void)didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;
#endif
+ (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
+ (void)didReceiveRemoteNotification:(NSDictionary *)notification;
#if !TARGET_OS_OSX
+ (void)didReceiveRemoteNotification:(NSDictionary *)notification fetchCompletionHandler:(RCTRemoteNotificationCallback)completionHandler;
+ (void)didReceiveLocalNotification:(UILocalNotification *)notification;
#endif
#if TARGET_OS_OSX
+ (void)didReceiveUserNotification:(NSUserNotification *)notification;
#endif
+ (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
#endif

@end
