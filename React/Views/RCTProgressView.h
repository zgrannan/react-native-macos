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
@interface RCTProgressView : UIProgressView
#else
@interface RCTProgressView : NSProgressIndicator
#endif

#if TARGET_OS_OSX
@property (nonatomic, strong, nullable) UIColor *progressTintColor;
@property (nonatomic, strong, nullable) UIColor *trackTintColor;
@property(nonatomic, strong, nullable) UIImage *progressImage;
@property(nonatomic, strong, nullable) UIImage *trackImage;
#endif

@end
