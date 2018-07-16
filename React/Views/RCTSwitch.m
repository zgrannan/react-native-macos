/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTSwitch.h"

#if TARGET_OS_OSX
#import <QuartzCore/QuartzCore.h>
#endif

#import "RCTEventDispatcher.h"
#import "UIView+React.h"

@implementation RCTSwitch

#if TARGET_OS_OSX
- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    self.buttonType = NSSwitchButton;
    self.title = @""; // default is "Button"
  }
  return self;
}
#endif

#if !TARGET_OS_OSX
- (void)setOn:(BOOL)on animated:(BOOL)animated {
  _wasOn = on;
  [super setOn:on animated:animated];
}
#endif

#if TARGET_OS_OSX

- (BOOL)on
{
  return self.state == NSOnState;
}

- (void)setOn:(BOOL)on
{
  self.state = on ? NSOnState : NSOffState;
}

#endif

@end
