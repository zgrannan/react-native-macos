/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTDevLoadingView.h"

#import <QuartzCore/QuartzCore.h>

#import "RCTBridge.h"
#import "RCTDefines.h"
#import "RCTDevSettings.h"
#import "RCTUtils.h"

#if RCT_DEV

static BOOL isEnabled = YES;

@implementation RCTDevLoadingView
{
#if !TARGET_OS_OSX
  UIWindow *_window;
  UILabel *_label;
#else
  NSWindow *_window;
  NSTextField *_label;
#endif
  NSDate *_showDate;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

+ (void)setEnabled:(BOOL)enabled
{
  isEnabled = enabled;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (void)setBridge:(RCTBridge *)bridge
{
  _bridge = bridge;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(hide)
                                               name:RCTJavaScriptDidLoadNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(hide)
                                               name:RCTJavaScriptDidFailToLoadNotification
                                             object:nil];

  if ([[bridge devSettings] isDevModeEnabled] && bridge.loading) {
    [self showWithURL:bridge.bundleURL];
  }
}

RCT_EXPORT_METHOD(showMessage:(NSString *)message color:(UIColor *)color backgroundColor:(UIColor *)backgroundColor)
{
  if (!isEnabled) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    self->_showDate = [NSDate date];
    if (!self->_window && !RCTRunningInTestEnvironment()) {
#if !TARGET_OS_OSX
      CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
      self->_window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 22)];
#if TARGET_OS_TV
      self->_window.windowLevel = UIWindowLevelNormal + 1;
#else
      self->_window.windowLevel = UIWindowLevelStatusBar + 1;
#endif
      // set a root VC so rotation is supported
      self->_window.rootViewController = [UIViewController new];

      self->_label = [[UILabel alloc] initWithFrame:self->_window.bounds];
      self->_label.font = [UIFont systemFontOfSize:12.0];
      self->_label.textAlignment = NSTextAlignmentCenter;

      [self->_window addSubview:self->_label];
#elif TARGET_OS_OSX
      NSRect screenFrame = [NSScreen mainScreen].visibleFrame;
      self->_window = [[NSPanel alloc] initWithContentRect:NSMakeRect(screenFrame.origin.x + round((screenFrame.size.width - 375) / 2), screenFrame.size.height - 22, 375, 22)
                                                 styleMask:NSWindowStyleMaskBorderless
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
      self->_window.releasedWhenClosed = NO;

      NSTextField *label = [[NSTextField alloc] initWithFrame:self->_window.contentView.bounds];
      label.alignment = NSTextAlignmentCenter;
      label.bezeled = NO;
      label.editable = NO;
      label.selectable = NO;
      self->_label = label;
      [[self->_window contentView] addSubview:label];
#endif
    }

#if !TARGET_OS_OSX
    self->_label.text = message;
    self->_label.textColor = color;
    self->_window.backgroundColor = backgroundColor;
    self->_window.hidden = NO;
#else
    self->_label.stringValue = message;
    self->_label.textColor = color;
    self->_label.backgroundColor = backgroundColor;
    [self->_window orderFront:nil];
#endif
  });
}

RCT_EXPORT_METHOD(hide)
{
  if (!isEnabled) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    const NSTimeInterval MIN_PRESENTED_TIME = 0.6;
    NSTimeInterval presentedTime = [[NSDate date] timeIntervalSinceDate:self->_showDate];
    NSTimeInterval delay = MAX(0, MIN_PRESENTED_TIME - presentedTime);
#if !TARGET_OS_OSX
    CGRect windowFrame = self->_window.frame;
    [UIView animateWithDuration:0.25
                          delay:delay
                        options:0
                     animations:^{
                       self->_window.frame = CGRectOffset(windowFrame, 0, -windowFrame.size.height);
                     } completion:^(__unused BOOL finished) {
                       self->_window.frame = windowFrame;
                       self->_window.hidden = YES;
                       self->_window = nil;
                     }];
#elif TARGET_OS_OSX
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [NSAnimationContext runAnimationGroup:^(__unused NSAnimationContext *context) {
        self->_window.animator.alphaValue = 0.0;
      } completionHandler:^{
        [self->_window orderFront:self];
        self->_window = nil;
      }];
    });
#endif
  });
}

- (void)showWithURL:(NSURL *)URL
{
  UIColor *color;
  UIColor *backgroundColor;
  NSString *source;
  if (URL.fileURL) {
    color = [UIColor grayColor];
    backgroundColor = [UIColor blackColor];
    source = @"pre-bundled file";
  } else {
    color = [UIColor whiteColor];
    backgroundColor = [UIColor colorWithHue:1./3 saturation:1 brightness:.35 alpha:1];
    source = [NSString stringWithFormat:@"%@:%@", URL.host, URL.port];
  }

  [self showMessage:[NSString stringWithFormat:@"Loading from %@...", source]
              color:color
    backgroundColor:backgroundColor];
}

- (void)updateProgress:(RCTLoadingProgress *)progress
{
  if (!progress) {
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_OSX
    self->_label.text = [progress description];
#else
    self->_label.stringValue = [progress description];
#endif
  });
}

@end

#else

@implementation RCTDevLoadingView

+ (NSString *)moduleName { return nil; }
+ (void)setEnabled:(BOOL)enabled { }
- (void)showWithURL:(NSURL *)URL { }
- (void)updateProgress:(RCTLoadingProgress *)progress { }
- (void)hide { }

@end

#endif
