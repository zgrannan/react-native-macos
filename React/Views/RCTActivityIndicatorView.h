/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <React/RCTUIKit.h>

@interface RCTActivityIndicatorView : UIActivityIndicatorView

#if TARGET_OS_OSX
@property (nonatomic, assign) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic, assign) BOOL hidesWhenStopped;
@property (nullable, readwrite, nonatomic, strong) UIColor *color;
@property (nonatomic, readonly, getter=isAnimating) BOOL animating;
- (void)startAnimating;
- (void)stopAnimating;
#endif

@end
