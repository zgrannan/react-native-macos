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

#if TARGET_OS_OSX
@protocol RCTSliderDelegate;
#endif

#if !TARGET_OS_OSX
@interface RCTSlider : UISlider
#else
@interface RCTSlider : NSSlider
#endif

#if TARGET_OS_OSX
@property (nonatomic, weak) id<RCTSliderDelegate> delegate;
@property (nonatomic, readonly) BOOL pressed;
@property (nonatomic, assign) float value;
@property (nonatomic, assign) float minimumValue;
@property (nonatomic, assign) float maximumValue;
@property (nonatomic, strong) NSColor *minimumTrackTintColor;
@property (nonatomic, strong) NSColor *maximumTrackTintColor;
- (void)setValue:(float)value animated:(BOOL)animated;
#endif

@property (nonatomic, copy) RCTBubblingEventBlock onValueChange;
@property (nonatomic, copy) RCTBubblingEventBlock onSlidingComplete;

@property (nonatomic, assign) float step;
@property (nonatomic, assign) float lastValue;

@property (nonatomic, strong) UIImage *trackImage;
@property (nonatomic, strong) UIImage *minimumTrackImage;
@property (nonatomic, strong) UIImage *maximumTrackImage;

@property (nonatomic, strong) UIImage *thumbImage;

@end

#if TARGET_OS_OSX
@protocol RCTSliderDelegate <NSObject>
@optional
- (void)slider:(RCTSlider *)slider didPress:(BOOL)press;
@end
#endif
