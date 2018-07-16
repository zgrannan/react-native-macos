/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTProgressViewManager.h"

#import "RCTConvert.h"
#import "RCTProgressView.h"

@implementation RCTConvert (RCTProgressViewManager)

#if TARGET_OS_OSX
RCT_ENUM_CONVERTER(NSProgressIndicatorStyle, (@{
  @"default": @(NSProgressIndicatorBarStyle),
  @"bar": @(NSProgressIndicatorBarStyle),
}), NSProgressIndicatorBarStyle, integerValue)
#else
RCT_ENUM_CONVERTER(UIProgressViewStyle, (@{
  @"default": @(UIProgressViewStyleDefault),
#if !TARGET_OS_TV
  @"bar": @(UIProgressViewStyleBar),
#endif
}), UIProgressViewStyleDefault, integerValue)
#endif

@end

@implementation RCTProgressViewManager

RCT_EXPORT_MODULE()

- (RCTPlatformView *)view
{
  return [RCTProgressView new];
}

#if !TARGET_OS_OSX
RCT_EXPORT_VIEW_PROPERTY(progressViewStyle, UIProgressViewStyle)
RCT_EXPORT_VIEW_PROPERTY(progress, float)
#else
RCT_EXPORT_VIEW_PROPERTY(style, NSProgressIndicatorStyle)
RCT_REMAP_VIEW_PROPERTY(progress, doubleValue, double)
#endif
RCT_EXPORT_VIEW_PROPERTY(progressTintColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(trackTintColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(progressImage, UIImage)
RCT_EXPORT_VIEW_PROPERTY(trackImage, UIImage)

@end
