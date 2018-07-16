/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <React/RCTBridge.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTUIKit.h>

#if !TARGET_OS_OSX
NSDictionary *RCTExportedDimensions(RCTBridge *bridge);
#else
NSDictionary *RCTExportedDimensions(RCTPlatformView *rootView);
#endif

@interface RCTDeviceInfo : NSObject <RCTBridgeModule, RCTInvalidating>

@end
