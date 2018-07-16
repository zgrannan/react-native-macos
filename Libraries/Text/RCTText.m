/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTText.h"

#if !TARGET_OS_OSX
#import <MobileCoreServices/UTCoreTypes.h>
#endif

#import <React/RCTAssert.h>
#import <React/RCTUtils.h>
#import <React/UIView+React.h>

#import "RCTShadowText.h"

#import <QuartzCore/QuartzCore.h>

static void collectNonTextDescendants(RCTText *view, NSMutableArray *nonTextDescendants)
{
  for (UIView *child in view.reactSubviews) {
    if ([child isKindOfClass:[RCTText class]]) {
      collectNonTextDescendants((RCTText *)child, nonTextDescendants);
    } else if (!CGRectEqualToRect(child.frame, CGRectZero)) {
      [nonTextDescendants addObject:child];
    }
  }
}

@implementation RCTText
{
  NSTextStorage *_textStorage;
  CAShapeLayer *_highlightLayer;
#if !TARGET_OS_OSX
  UILongPressGestureRecognizer *_longPressGestureRecognizer;
#endif
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    _textStorage = [NSTextStorage new];
#if !TARGET_OS_OSX
    self.isAccessibilityElement = YES;
    self.accessibilityTraits |= UIAccessibilityTraitStaticText;
#else
    self.accessibilityRole = NSAccessibilityStaticTextRole;
#endif

    self.opaque = NO;
    UIViewSetContentModeRedraw(self);
  }
  return self;
}

#if TARGET_OS_OSX
-(BOOL)canBecomeKeyView
{
	//RCTText should not get any keyboard focus
	return NO;
}
#endif

- (NSString *)description
{
  NSString *superDescription = super.description;
  NSRange semicolonRange = [superDescription rangeOfString:@";"];
  if (semicolonRange.location == NSNotFound) {
    return [[superDescription substringToIndex:superDescription.length - 1] stringByAppendingFormat:@"; reactTag: %@; text: %@, frame = %@; layer = %@>", self.reactTag, self.textStorage.string, NSStringFromCGRect(self.frame), self.layer];
  } else {
    NSString *replacement = [NSString stringWithFormat:@"; reactTag: %@; text: %@", self.reactTag, self.textStorage.string];
    return [superDescription stringByReplacingCharactersInRange:semicolonRange withString:replacement];
	}
}

- (void)setSelectable:(BOOL)selectable
{
  if (_selectable == selectable) {
    return;
  }

  _selectable = selectable;

#if !TARGET_OS_OSX
  if (_selectable) {
    [self enableContextMenu];
  }
  else {
    [self disableContextMenu];
  }
#endif
}

#if !TARGET_OS_OSX
- (void)reactSetFrame:(CGRect)frame
{
  // Text looks super weird if its frame is animated.
  // This disables the frame animation, without affecting opacity, etc.
  [UIView performWithoutAnimation:^{
    [super reactSetFrame:frame];
  }];
}
#endif

- (void)reactSetInheritedBackgroundColor:(UIColor *)inheritedBackgroundColor
{
  self.backgroundColor = inheritedBackgroundColor;
}

- (void)didUpdateReactSubviews
{
  // Do nothing, as subviews are managed by `setTextStorage:` method
}

- (void)setTextStorage:(NSTextStorage *)textStorage
{
  if (_textStorage != textStorage) {
    _textStorage = textStorage;

    // Update subviews
    NSMutableArray *nonTextDescendants = [NSMutableArray new];
    collectNonTextDescendants(self, nonTextDescendants);
    NSArray *subviews = self.subviews;
    if (![subviews isEqualToArray:nonTextDescendants]) {
      for (UIView *child in subviews) {
        if (![nonTextDescendants containsObject:child]) {
          [child removeFromSuperview];
        }
      }
      for (UIView *child in nonTextDescendants) {
        [self addSubview:child];
      }
    }

    [self setNeedsDisplay];
  }
}

- (void)drawRect:(CGRect)rect
{
  NSLayoutManager *layoutManager = [_textStorage.layoutManagers firstObject];
  NSTextContainer *textContainer = [layoutManager.textContainers firstObject];

  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  CGRect textFrame = self.textFrame;
  [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:textFrame.origin];
  [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:textFrame.origin];

  __block CGMutablePathRef highlightPath = NULL;
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
  [layoutManager.textStorage enumerateAttribute:RCTIsHighlightedAttributeName inRange:characterRange options:0 usingBlock:^(NSNumber *value, NSRange range, BOOL *_) {
    if (!value.boolValue) {
      return;
    }

    [layoutManager enumerateEnclosingRectsForGlyphRange:range withinSelectedGlyphRange:range inTextContainer:textContainer usingBlock:^(CGRect enclosingRect, __unused BOOL *__) {
      if (highlightPath == NULL) {
        highlightPath = CGPathCreateMutable();
      }
      CGPathAddRoundedRect(highlightPath, NULL, CGRectInset(enclosingRect, -2, -2), 2, 2);
    }];
  }];

  if (highlightPath) {
    if (!_highlightLayer) {
      _highlightLayer = [CAShapeLayer layer];
      _highlightLayer.fillColor = [UIColor colorWithWhite:0 alpha:0.25].CGColor;
      [self.layer addSublayer:_highlightLayer];
    }
    _highlightLayer.position = (CGPoint){_contentInset.left, _contentInset.top};
    _highlightLayer.path = highlightPath;
    CFRelease(highlightPath);
  } else {
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  }
}

- (NSNumber *)reactTagAtPoint:(CGPoint)point
{
  NSNumber *reactTag = self.reactTag;

  CGFloat fraction;
  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  NSUInteger characterIndex = [layoutManager characterIndexForPoint:point
                                                    inTextContainer:textContainer
                           fractionOfDistanceBetweenInsertionPoints:&fraction];

  // If the point is not before (fraction == 0.0) the first character and not
  // after (fraction == 1.0) the last character, then the attribute is valid.
  if (_textStorage.length > 0 && (fraction > 0 || characterIndex > 0) && (fraction < 1 || characterIndex < _textStorage.length - 1)) {
    reactTag = [_textStorage attribute:RCTReactTagAttributeName atIndex:characterIndex effectiveRange:NULL];
  }
  return reactTag;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (!self.window) {
    self.layer.contents = nil;
    if (_highlightLayer) {
      [_highlightLayer removeFromSuperlayer];
      _highlightLayer = nil;
    }
  } else if (_textStorage.length) {
    [self setNeedsDisplay];
  }
}


#pragma mark - Accessibility

- (NSString *)accessibilityLabel
{
  NSString *superAccessibilityLabel = [super accessibilityLabel];
  if (superAccessibilityLabel) {
    return superAccessibilityLabel;
  }
  return _textStorage.string;
}

#pragma mark - Context Menu

#if !TARGET_OS_OSX
- (void)enableContextMenu
{
  _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  [self addGestureRecognizer:_longPressGestureRecognizer];
}

- (void)disableContextMenu
{
  [self removeGestureRecognizer:_longPressGestureRecognizer];
  _longPressGestureRecognizer = nil;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
#if !TARGET_OS_TV
  UIMenuController *menuController = [UIMenuController sharedMenuController];

  if (menuController.isMenuVisible) {
    return;
  }

  if (!self.isFirstResponder) {
    [self becomeFirstResponder];
  }

  [menuController setTargetRect:self.bounds inView:self];
  [menuController setMenuVisible:YES animated:YES];
#endif
}
#else

- (void)rightMouseDown:(NSEvent *)event
{
  if (_selectable == NO) {
    return;
  }
  NSText *fieldEditor = [self.window fieldEditor:YES forObject:self];
  NSMenu *fieldEditorMenu = [fieldEditor menuForEvent:event];

  RCTAssert(fieldEditorMenu, @"Unable to obtain fieldEditor's context menu");

  if (fieldEditorMenu) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

    for (NSMenuItem *fieldEditorMenuItem in fieldEditorMenu.itemArray) {
      if (fieldEditorMenuItem.action == @selector(copy:)) {
        NSMenuItem *item = [fieldEditorMenuItem copy];

        item.target = self;
        [menu addItem:item];

        break;
      }
    }

    RCTAssert(menu.numberOfItems > 0, @"Unable to create context menu with \"Copy\" item");

    if (menu.numberOfItems > 0) {
      [NSMenu popUpContextMenu:menu withEvent:event forView:self];
    }
  }
}
#endif

- (BOOL)canBecomeFirstResponder
{
  return _selectable;
}

#if !TARGET_OS_OSX
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (_selectable && action == @selector(copy:)) {
    return YES;
  }
  
  return [self.nextResponder canPerformAction:action withSender:sender];
}
#endif

- (void)copy:(id)sender
{
#if !TARGET_OS_TV
  NSAttributedString *attributedString = _textStorage;

  NSData *rtf = [attributedString dataFromRange:NSMakeRange(0, attributedString.length)
                             documentAttributes:@{NSDocumentTypeDocumentAttribute: NSRTFDTextDocumentType}
                                          error:nil];

#if TARGET_OS_IPHONE
  NSMutableDictionary *item = [NSMutableDictionary new];

  if (rtf) {
    [item setObject:rtf forKey:(id)kUTTypeFlatRTFD];
  }

  [item setObject:attributedString.string forKey:(id)kUTTypeUTF8PlainText];

  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  pasteboard.items = @[item];
#elif TARGET_OS_OSX
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard writeObjects:[NSArray arrayWithObjects:attributedString.string, rtf, nil]];
#endif
#endif
}

@end
