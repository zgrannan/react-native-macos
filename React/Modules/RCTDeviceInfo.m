/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTDeviceInfo.h"

#import "RCTAccessibilityManager.h"
#import "RCTAssert.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"
#import "RCTUIKit.h"
#import "UIView+React.h"

@implementation RCTDeviceInfo {
#if !TARGET_OS_TV && !TARGET_OS_OSX
  UIInterfaceOrientation _currentInterfaceOrientation;
#endif
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)setBridge:(RCTBridge *)bridge
{
  _bridge = bridge;

#if !TARGET_OS_OSX
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveNewContentSizeMultiplier)
                                               name:RCTAccessibilityManagerDidUpdateMultiplierNotification
                                             object:_bridge.accessibilityManager];
#endif
  
#if !TARGET_OS_TV && !TARGET_OS_OSX
  _currentInterfaceOrientation = [RCTSharedApplication() statusBarOrientation];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(interfaceOrientationDidChange)
                                               name:UIApplicationDidChangeStatusBarOrientationNotification
                                             object:nil];
#endif
}

static BOOL RCTIsIPhoneX() {
  static BOOL isIPhoneX = NO;
#if !TARGET_OS_OSX
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    RCTAssertMainQueue();

    isIPhoneX = CGSizeEqualToSize(
      [UIScreen mainScreen].nativeBounds.size,
      CGSizeMake(1125, 2436)
    );
  });
#endif
  return isIPhoneX;
}

#if !TARGET_OS_OSX
NSDictionary *RCTExportedDimensions(RCTBridge *bridge)
#else
NSDictionary *RCTExportedDimensions(RCTPlatformView *rootView)
#endif
{
  RCTAssertMainQueue();

  // Don't use RCTScreenSize since it the interface orientation doesn't apply to it
#if !TARGET_OS_OSX
	CGRect screenSize = [[UIScreen mainScreen] bounds];
  NSDictionary *dims = @{
                         @"width": @(screenSize.size.width),
                         @"height": @(screenSize.size.height),
                         @"scale": @(RCTScreenScale()),
                         @"fontScale": @(bridge.accessibilityManager.multiplier)
                         };
  return @{
           @"window": dims,
           @"screen": dims
           };
#else
	if (rootView != nil) {
		NSWindow *window = rootView.window;
		if (window != nil) {
			NSSize size = rootView.bounds.size;
			return @{
				@"window": @{
					@"width": @(size.width),
					@"height": @(size.height),
					@"scale": @(window.backingScaleFactor),
				},
        @"rootTag" : rootView.reactTag,
			};
		}
	}

  // We don't have a root view or window yet so make something up
  NSScreen *screen = [NSScreen screens].firstObject;
  return @{
      @"window": @{
        @"width": @(screen.frame.size.width),
        @"height": @(screen.frame.size.height),
        @"scale": @(screen.backingScaleFactor),
      },
  };
#endif
}

- (void)dealloc
{
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)invalidate
{
  RCTExecuteOnMainQueue(^{
    self->_bridge = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  });
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
  return @{
#if !TARGET_OS_OSX
    @"Dimensions": RCTExportedDimensions(_bridge),
#else
    @"Dimensions": RCTExportedDimensions(nil),
#endif
    // Note:
    // This prop is deprecated and will be removed right after June 01, 2018.
    // Please use this only for a quick and temporary solution.
    // Use <SafeAreaView> instead.
    @"isIPhoneX_deprecated": @(RCTIsIPhoneX()),
  };
}

- (void)didReceiveNewContentSizeMultiplier
{
  RCTBridge *bridge = _bridge;
  RCTExecuteOnMainQueue(^{
    // Report the event across the bridge.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [bridge.eventDispatcher sendDeviceEventWithName:@"didUpdateDimensions"
#if !TARGET_OS_OSX
    body:RCTExportedDimensions(bridge)];
#else
    body:RCTExportedDimensions(nil)];
#endif
#pragma clang diagnostic pop
  });
}

#if !TARGET_OS_TV && !TARGET_OS_OSX

- (void)interfaceOrientationDidChange
{
  __weak typeof(self) weakSelf = self;
  RCTExecuteOnMainQueue(^{
    [weakSelf _interfaceOrientationDidChange];
  });
}


- (void)_interfaceOrientationDidChange
{
  UIInterfaceOrientation nextOrientation = [RCTSharedApplication() statusBarOrientation];

  // Update when we go from portrait to landscape, or landscape to portrait
  if ((UIInterfaceOrientationIsPortrait(_currentInterfaceOrientation) &&
       !UIInterfaceOrientationIsPortrait(nextOrientation)) ||
      (UIInterfaceOrientationIsLandscape(_currentInterfaceOrientation) &&
       !UIInterfaceOrientationIsLandscape(nextOrientation))) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [_bridge.eventDispatcher sendDeviceEventWithName:@"didUpdateDimensions"
                                                    body:RCTExportedDimensions(_bridge)];
#pragma clang diagnostic pop
      }

  _currentInterfaceOrientation = nextOrientation;
}

#endif // TARGET_OS_TV


@end
