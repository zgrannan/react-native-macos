/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <React/RCTComponent.h>
#import <React/RCTUIKit.h>

#if !TARGET_OS_OSX
@interface RCTSegmentedControl : UISegmentedControl
#else
@interface RCTSegmentedControl : NSSegmentedControl
#endif

#if TARGET_OS_OSX
@property (nonatomic, assign, getter = isMomentary) BOOL momentary;
#endif

@property (nonatomic, copy) NSArray<NSString *> *values;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) RCTBubblingEventBlock onChange;

@end
