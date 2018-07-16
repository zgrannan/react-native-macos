/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTTouchHandler.h"

#if !TARGET_OS_OSX
#import <UIKit/UIGestureRecognizerSubclass.h>
#endif

#import "RCTAssert.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#import "RCTTouchEvent.h"
#import "RCTUIManager.h"
#import "RCTUtils.h"
#import "UIView+React.h"

@interface RCTTouchHandler () <UIGestureRecognizerDelegate>
@end

// TODO: this class behaves a lot like a module, and could be implemented as a
// module if we were to assume that modules and RootViews had a 1:1 relationship
@implementation RCTTouchHandler
{
  __weak RCTEventDispatcher *_eventDispatcher;

  /**
   * Arrays managed in parallel tracking native touch object along with the
   * native view that was touched, and the React touch data dictionary.
   * These must be kept track of because `UIKit` destroys the touch targets
   * if touches are canceled, and we have no other way to recover this info.
   */
  NSMutableOrderedSet *_nativeTouches;
  NSMutableArray<NSMutableDictionary *> *_reactTouches;
  NSMutableArray<RCTPlatformView *> *_touchViews;

  uint16_t _coalescingKey;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  RCTAssertParam(bridge);

  if ((self = [super initWithTarget:nil action:NULL])) {
    _eventDispatcher = [bridge moduleForClass:[RCTEventDispatcher class]];

    _nativeTouches = [NSMutableOrderedSet new];
    _reactTouches = [NSMutableArray new];
    _touchViews = [NSMutableArray new];
#if !TARGET_OS_OSX
    // `cancelsTouchesInView` and `delaysTouches*` are needed in order to be used as a top level
    // event delegated recognizer. Otherwise, lower-level components not built
    // using RCT, will fail to recognize gestures.
    self.cancelsTouchesInView = NO;
    self.delaysTouchesBegan = NO; // This is default value.
    self.delaysTouchesEnded = NO;
#else
    self.delaysPrimaryMouseButtonEvents = NO; // default is NO.
    self.delaysSecondaryMouseButtonEvents = NO; // default is NO.
    self.delaysOtherMouseButtonEvents = NO; // default is NO.
#endif

    self.delegate = self;
  }

  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithTarget:(id)target action:(SEL)action)
#if TARGET_OS_OSX
RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)coder)
#endif

- (void)attachToView:(UIView *)view
{
  RCTAssert(self.view == nil, @"RCTTouchHandler already has attached view.");

  [view addGestureRecognizer:self];
}

- (void)detachFromView:(UIView *)view
{
  RCTAssertParam(view);
  RCTAssert(self.view == view, @"RCTTouchHandler attached to another view.");

  [view removeGestureRecognizer:self];
}

#pragma mark - Bookkeeping for touch indices

- (void)_recordNewTouches:(NSSet *)touches
{
#if !TARGET_OS_OSX
  for (UITouch *touch in touches) {
#else
  for (NSEvent *touch in touches) {
#endif

    RCTAssert(![_nativeTouches containsObject:touch],
              @"Touch is already recorded. This is a critical bug.");

    // Find closest React-managed touchable view
    
#if !TARGET_OS_OSX
    RCTPlatformView *targetView = touch.view;	
    while (targetView) {
      if (targetView.reactTag && targetView.isUserInteractionEnabled) {
        break;
      }
      targetView = targetView.superview;
    }
    
    CGPoint touchLocation = [touch locationInView:targetView];
    NSNumber *reactTag = [targetView reactTagAtPoint:touchLocation];
    if (!reactTag || !targetView.isUserInteractionEnabled) {
      continue;
    }
#else
    CGPoint touchLocation = [self.view convertPoint:touch.locationInWindow fromView:nil];
    NSView *targetView = [self.view hitTest:touchLocation];
    touchLocation = [targetView convertPoint:touchLocation fromView:self.view];
    
    while (targetView) {
      BOOL isUserInteractionEnabled = NO;
      if ([((UIView*)targetView) respondsToSelector:@selector(isUserInteractionEnabled)]) {
        isUserInteractionEnabled = ((UIView*)targetView).isUserInteractionEnabled;
      }
      if (targetView.reactTag && isUserInteractionEnabled) {
        break;
      }
      targetView = targetView.superview;
    }

    NSNumber *reactTag = [targetView reactTagAtPoint:touchLocation];
    BOOL isUserInteractionEnabled = NO;
    if ([((UIView*)targetView) respondsToSelector:@selector(isUserInteractionEnabled)]) {
      isUserInteractionEnabled = ((UIView*)targetView).isUserInteractionEnabled;
    }
    if (!reactTag || !isUserInteractionEnabled) {
      continue;
    }
#endif

    // Get new, unique touch identifier for the react touch
    const NSUInteger RCTMaxTouches = 11; // This is the maximum supported by iDevices
    NSInteger touchID = ([_reactTouches.lastObject[@"identifier"] integerValue] + 1) % RCTMaxTouches;
    touchID = [self _eventWithNumber:touchID];

    // Create touch
    NSMutableDictionary *reactTouch = [[NSMutableDictionary alloc] initWithCapacity:RCTMaxTouches];
    reactTouch[@"target"] = reactTag;
    reactTouch[@"identifier"] = @(touchID);

    // Add to arrays
    [_touchViews addObject:targetView];
    [_nativeTouches addObject:touch];
    [_reactTouches addObject:reactTouch];
  }
}

- (NSInteger)_eventWithNumber:(NSInteger)touchID
{
  for (NSDictionary *reactTouch in _reactTouches) {
    NSInteger usedID = [reactTouch[@"identifier"] integerValue];
    if (usedID == touchID) {
      // ID has already been used, try next value
      touchID ++;
    } else if (usedID > touchID) {
      // If usedID > touchID, touchID must be unique, so we can stop looking
      break;
    }
  }
  return touchID;
}

- (void)_recordRemovedTouches:(NSSet *)touches
{
#if !TARGET_OS_OSX
  for (UITouch *touch in touches) {
    NSInteger index = [_nativeTouches indexOfObject:touch];
#else
    for (NSEvent *touch in touches) {
      NSInteger index = [_nativeTouches indexOfObjectPassingTest:^BOOL(NSEvent *event, __unused NSUInteger idx, __unused BOOL *stop) {
        return touch.eventNumber == event.eventNumber;
      }];
#endif
    if (index == NSNotFound) {
      continue;
    }

    [_touchViews removeObjectAtIndex:index];
    [_nativeTouches removeObjectAtIndex:index];
    [_reactTouches removeObjectAtIndex:index];
  }
}

- (void)_updateReactTouchAtIndex:(NSInteger)touchIndex
{
#if !TARGET_OS_OSX
  UITouch *nativeTouch = _nativeTouches[touchIndex];
  CGPoint windowLocation = [nativeTouch locationInView:nativeTouch.window];
  CGPoint rootViewLocation = [nativeTouch.window convertPoint:windowLocation toView:self.view];

  RCTPlatformView *touchView = _touchViews[touchIndex];
  CGPoint touchViewLocation = [nativeTouch.window convertPoint:windowLocation toView:touchView];
#else
  NSEvent *nativeTouch = _nativeTouches[touchIndex];
  CGPoint location = nativeTouch.locationInWindow;
  CGPoint rootViewLocation = CGPointMake(location.x, CGRectGetHeight(self.view.window.frame) - location.y);
  CGPoint touchViewLocation = rootViewLocation;
#endif

  NSMutableDictionary *reactTouch = _reactTouches[touchIndex];
  reactTouch[@"pageX"] = @(RCTSanitizeNaNValue(rootViewLocation.x, @"touchEvent.pageX"));
  reactTouch[@"pageY"] = @(RCTSanitizeNaNValue(rootViewLocation.y, @"touchEvent.pageY"));
  reactTouch[@"locationX"] = @(RCTSanitizeNaNValue(touchViewLocation.x, @"touchEvent.locationX"));
  reactTouch[@"locationY"] = @(RCTSanitizeNaNValue(touchViewLocation.y, @"touchEvent.locationY"));
  reactTouch[@"timestamp"] =  @(nativeTouch.timestamp * 1000); // in ms, for JS
#if !TARGET_OS_OSX
  // TODO: force for a 'normal' touch is usually 1.0;
  // should we expose a `normalTouchForce` constant somewhere (which would
  // have a value of `1.0 / nativeTouch.maximumPossibleForce`)?
  if (RCTForceTouchAvailable()) {
    if (@available(iOS 9.0, *)) {
      reactTouch[@"force"] = @(RCTZeroIfNaN(nativeTouch.force / nativeTouch.maximumPossibleForce));
    } else {
      reactTouch[@"force"] = @(0);
    }
  }
#else
  NSEventModifierFlags modifierFlags = nativeTouch.modifierFlags;
  if (modifierFlags & NSEventModifierFlagShift) {
    reactTouch[@"shiftKey"] = @YES;
  }
  if (modifierFlags & NSEventModifierFlagControl) {
    reactTouch[@"ctrlKey"] = @YES;
  }
  if (modifierFlags & NSEventModifierFlagOption) {
    reactTouch[@"altKey"] = @YES;
  }
  if (modifierFlags & NSEventModifierFlagCommand) {
    reactTouch[@"metaKey"] = @YES;
  }
  
  NSEventType type = nativeTouch.type;
  if (type == NSEventTypeLeftMouseDown || type == NSEventTypeLeftMouseUp || type == NSEventTypeLeftMouseDragged) {
    reactTouch[@"button"] = @0;
  } else if (type == NSEventTypeRightMouseDown || type == NSEventTypeRightMouseUp || type == NSEventTypeRightMouseDragged) {
    reactTouch[@"button"] = @2;
  }
#endif
}

/**
 * Constructs information about touch events to send across the serialized
 * boundary. This data should be compliant with W3C `Touch` objects. This data
 * alone isn't sufficient to construct W3C `Event` objects. To construct that,
 * there must be a simple receiver on the other side of the bridge that
 * organizes the touch objects into `Event`s.
 *
 * We send the data as an array of `Touch`es, the type of action
 * (start/end/move/cancel) and the indices that represent "changed" `Touch`es
 * from that array.
 */
- (void)_updateAndDispatchTouches:(NSSet *)touches
                        eventName:(NSString *)eventName
{
  // Update touches
  NSMutableArray<NSNumber *> *changedIndexes = [NSMutableArray new];
#if !TARGET_OS_OSX
  for (UITouch *touch in touches) {
    NSInteger index = [_nativeTouches indexOfObject:touch];
#else
  for (NSEvent *touch in touches) {
    NSInteger index = [_nativeTouches indexOfObjectPassingTest:^BOOL(NSEvent *event, __unused NSUInteger idx, __unused BOOL *stop) {
      return touch.eventNumber == event.eventNumber;
    }];
#endif
    
    if (index == NSNotFound) {
      continue;
    }
    
#if TARGET_OS_OSX
    _nativeTouches[index] = touch;
#endif

    [self _updateReactTouchAtIndex:index];
    [changedIndexes addObject:@(index)];
  }

  if (changedIndexes.count == 0) {
    return;
  }

  // Deep copy the touches because they will be accessed from another thread
  // TODO: would it be safer to do this in the bridge or executor, rather than trusting caller?
  NSMutableArray<NSDictionary *> *reactTouches =
  [[NSMutableArray alloc] initWithCapacity:_reactTouches.count];
  for (NSDictionary *touch in _reactTouches) {
    [reactTouches addObject:[touch copy]];
  }

  BOOL canBeCoalesced = [eventName isEqualToString:@"touchMove"];

  // We increment `_coalescingKey` twice here just for sure that
  // this `_coalescingKey` will not be reused by ahother (preceding or following) event
  // (yes, even if coalescing only happens (and makes sense) on events of the same type).

  if (!canBeCoalesced) {
    _coalescingKey++;
  }

  RCTTouchEvent *event = [[RCTTouchEvent alloc] initWithEventName:eventName
                                                         reactTag:self.view.reactTag
                                                     reactTouches:reactTouches
                                                   changedIndexes:changedIndexes
                                                    coalescingKey:_coalescingKey];

  if (!canBeCoalesced) {
    _coalescingKey++;
  }

  [_eventDispatcher sendEvent:event];
}

#pragma mark - Gesture Recognizer Delegate Callbacks

#if !TARGET_OS_OSX
static BOOL RCTAllTouchesAreCancelledOrEnded(NSSet *touches)
{
  for (UITouch *touch in touches) {
    if (touch.phase == UITouchPhaseBegan ||
        touch.phase == UITouchPhaseMoved ||
        touch.phase == UITouchPhaseStationary) {
      return NO;
    }
  }
  return YES;
}

static BOOL RCTAnyTouchesChanged(NSSet *touches)
{
  for (UITouch *touch in touches) {
    if (touch.phase == UITouchPhaseBegan ||
        touch.phase == UITouchPhaseMoved) {
      return YES;
    }
  }
  return NO;
}
#endif

#pragma mark - `UIResponder`-ish touch-delivery methods

- (void)interactionsBegan:(NSSet *)touches
{
  // "start" has to record new touches *before* extracting the event.
  // "end"/"cancel" needs to remove the touch *after* extracting the event.
  [self _recordNewTouches:touches];

  [self _updateAndDispatchTouches:touches eventName:@"touchStart"];

  if (self.state == UIGestureRecognizerStatePossible) {
    self.state = UIGestureRecognizerStateBegan;
  } else if (self.state == UIGestureRecognizerStateBegan) {
    self.state = UIGestureRecognizerStateChanged;
  }
}

- (void)interactionsMoved:(NSSet *)touches
{
  [self _updateAndDispatchTouches:touches eventName:@"touchMove"];
  self.state = UIGestureRecognizerStateChanged;
}

- (void)interactionsEnded:(NSSet *)touches withEvent:(UIEvent*)event
{
  [self _updateAndDispatchTouches:touches eventName:@"touchEnd"];
#if !TARGET_OS_OSX
  if (RCTAllTouchesAreCancelledOrEnded(event.allTouches)) {
    self.state = UIGestureRecognizerStateEnded;
  } else if (RCTAnyTouchesChanged(event.allTouches)) {
    self.state = UIGestureRecognizerStateChanged;
  }
#else
  self.state = UIGestureRecognizerStateEnded;
#endif

  [self _recordRemovedTouches:touches];
}

- (void)interactionsCancelled:(NSSet *)touches withEvent:(UIEvent*)event
{
  [self _updateAndDispatchTouches:touches eventName:@"touchCancel"];
#if !TARGET_OS_OSX
  if (RCTAllTouchesAreCancelledOrEnded(event.allTouches)) {
    self.state = UIGestureRecognizerStateCancelled;
  } else if (RCTAnyTouchesChanged(event.allTouches)) {
    self.state = UIGestureRecognizerStateChanged;
  }
#else
  self.state = UIGestureRecognizerStateCancelled;
#endif
  
  [self _recordRemovedTouches:touches];
}
  
#if !TARGET_OS_OSX
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [super touchesBegan:touches withEvent:event];
  [self interactionsBegan:touches];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [super touchesMoved:touches withEvent:event];
  [self interactionsMoved:touches];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [super touchesEnded:touches withEvent:event];
  [self interactionsEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [super touchesCancelled:touches withEvent:event];
  [self interactionsCancelled:touches withEvent:event];
}
#else
  
- (void)mouseDown:(NSEvent *)event
{
  [super mouseDown:event];
  [self interactionsBegan:[NSSet setWithObject:event]];
}
  
- (void)rightMouseDown:(NSEvent *)event
{
  [super rightMouseDown:event];
  [self interactionsBegan:[NSSet setWithObject:event]];
}
  
- (void)mouseDragged:(NSEvent *)event
{
  [super mouseDragged:event];
  [self interactionsMoved:[NSSet setWithObject:event]];
}
  
- (void)rightMouseDragged:(NSEvent *)event
{
  [super rightMouseDragged:event];
  [self interactionsMoved:[NSSet setWithObject:event]];
}

- (void)mouseUp:(NSEvent *)event
{
  [super mouseUp:event];
  [self interactionsEnded:[NSSet setWithObject:event] withEvent:event];
}
  
- (void)rightMouseUp:(NSEvent *)event
{
  [super rightMouseUp:event];
  [self interactionsEnded:[NSSet setWithObject:event] withEvent:event];
}
  
#endif

- (BOOL)canPreventGestureRecognizer:(__unused UIGestureRecognizer *)preventedGestureRecognizer
{
  return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
  // We fail in favour of other external gesture recognizers.
  // iOS will ask `delegate`'s opinion about this gesture recognizer little bit later.
  return !UIViewIsDescendantOfView(preventingGestureRecognizer.view, self.view);
}

- (void)reset
{
  if (_nativeTouches.count != 0) {
    [self _updateAndDispatchTouches:_nativeTouches.set eventName:@"touchCancel"];

    [_nativeTouches removeAllObjects];
    [_reactTouches removeAllObjects];
    [_touchViews removeAllObjects];
  }
}

#pragma mark - Other

- (void)cancel
{
  self.enabled = NO;
  self.enabled = YES;
}

#if TARGET_OS_OSX
- (void)willShowMenuWithEvent:(NSEvent*)event
{
  if (event.type == NSEventTypeRightMouseDown) {
    [self interactionsEnded:[NSSet setWithObject:event] withEvent:event];
  }
}
#endif

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(__unused UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  // Same condition for `failure of` as for `be prevented by`.
  return [self canBePreventedByGestureRecognizer:otherGestureRecognizer];
}

@end
