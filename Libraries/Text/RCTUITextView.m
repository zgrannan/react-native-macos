/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTUITextView.h"

#import <React/RCTUtils.h>
#import <React/UIView+React.h>

#import "RCTBackedTextInputDelegateAdapter.h"

@implementation RCTUITextView
{
#if !TARGET_OS_OSX
  UILabel *_placeholderView;
  UITextView *_detachedTextView;
#endif
  RCTBackedTextViewDelegateAdapter *_textInputDelegateAdapter;
}

static UIFont *defaultPlaceholderFont()
{
  return [UIFont systemFontOfSize:17];
}

static UIColor *defaultPlaceholderColor()
{
  // Default placeholder color from UITextField.
  return [UIColor colorWithRed:0 green:0 blue:0.0980392 alpha:0.22];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textDidChange)
                                                 name:UITextViewTextDidChangeNotification
                                               object:self];
#if !TARGET_OS_OSX
    _placeholderView = [[UILabel alloc] initWithFrame:self.bounds];
    _placeholderView.isAccessibilityElement = NO;
    _placeholderView.numberOfLines = 0;
    _placeholderView.textColor = defaultPlaceholderColor();
    [self addSubview:_placeholderView];
#else
    NSTextCheckingTypes checkingTypes = 0;
    self.enabledTextCheckingTypes = checkingTypes;
#endif

    _textInputDelegateAdapter = [[RCTBackedTextViewDelegateAdapter alloc] initWithTextView:self];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)accessibilityLabel
{
  NSMutableString *accessibilityLabel = [NSMutableString new];
  
  NSString *superAccessibilityLabel = [super accessibilityLabel];
  if (superAccessibilityLabel.length > 0) {
    [accessibilityLabel appendString:superAccessibilityLabel];
  }
  
  if (self.placeholder.length > 0 && self.text.length == 0) {
    if (accessibilityLabel.length > 0) {
      [accessibilityLabel appendString:@" "];
    }
    [accessibilityLabel appendString:self.placeholder];
  }
  
  return accessibilityLabel;
}

#pragma mark - Properties

- (void)setPlaceholder:(NSString *)placeholder
{
  _placeholder = placeholder;
#if !TARGET_OS_OSX
  _placeholderView.text = _placeholder;
#else
  [self setNeedsDisplay:YES];
#endif
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  _placeholderColor = placeholderColor;
#if !TARGET_OS_OSX
  _placeholderView.textColor = _placeholderColor ?: defaultPlaceholderColor();
#else
  [self setNeedsDisplay:YES];
#endif
}

#if TARGET_OS_OSX
- (void)setSelectionColor:(UIColor *)selectionColor
{
  NSMutableDictionary *selectTextAttributes = self.selectedTextAttributes.mutableCopy;
  selectTextAttributes[NSBackgroundColorAttributeName] = selectionColor ?: [NSColor selectedControlColor];
  self.selectedTextAttributes = selectTextAttributes.copy;
}

- (UIColor*)selectionColor
{
  return (UIColor*)self.selectedTextAttributes[NSBackgroundColorAttributeName];
}

- (void)setEnabledTextCheckingTypes:(NSTextCheckingTypes)checkingType
{
  [super setEnabledTextCheckingTypes:checkingType];
  self.automaticDataDetectionEnabled = checkingType != 0;
}

- (NSTextAlignment)textAlignment
{
  return self.alignment;
}

- (NSString*)text
{
  return self.string;
}

- (NSAttributedString*)attributedText
{
  return self.textStorage;
}

- (BOOL)becomeFirstResponder
{
  return [self.window makeFirstResponder:self];
}

#endif // TARGET_OS_OSX

- (void)textDidChange
{
  _textWasPasted = NO;
  [self invalidatePlaceholderVisibility];
}

#pragma mark - Overrides

- (void)setFont:(UIFont *)font
{
  [super setFont:font];
#if !TARGET_OS_OSX
  _placeholderView.font = font ?: defaultPlaceholderFont();
#else
  [self setNeedsDisplay:YES];
#endif
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
#if !TARGET_OS_OSX
  [super setTextAlignment:textAlignment];
  _placeholderView.textAlignment = textAlignment;
#else
  self.alignment = textAlignment;
  [self setNeedsDisplay:YES];
#endif
}

- (void)setText:(NSString *)text
{
#if !TARGET_OS_OSX
  [super setText:text];
#else
  self.string = text.copy;
#endif
  
  [self textDidChange];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
#if !TARGET_OS_OSX
  [super setAttributedText:attributedText];
#else
  [self.textStorage setAttributedString:attributedText];
#endif
  
  [self textDidChange];
}

#pragma mark - Overrides

#if !TARGET_OS_OSX
- (void)setSelectedTextRange:(UITextRange *)selectedTextRange notifyDelegate:(BOOL)notifyDelegate
#else
- (void)setSelectedTextRange:(NSRange)selectedTextRange notifyDelegate:(BOOL)notifyDelegate
#endif
{
  if (!notifyDelegate) {
    // We have to notify an adapter that following selection change was initiated programmatically,
    // so the adapter must not generate a notification for it.
    [_textInputDelegateAdapter skipNextTextInputDidChangeSelectionEventWithTextRange:selectedTextRange];
  }

#if !TARGET_OS_OSX
  [super setSelectedTextRange:selectedTextRange];
#else
  [super setSelectedRange:selectedTextRange];
#endif
}

#if TARGET_OS_OSX
- (NSRange)selectedTextRange
{
  return [super selectedRange];
}
#endif

- (void)paste:(id)sender
{
  [super paste:sender];
  _textWasPasted = YES;
}

#if !TARGET_OS_OSX
- (void)setContentOffset:(CGPoint)contentOffset animated:(__unused BOOL)animated
{
  // Turning off scroll animation.
  // This fixes the problem also known as "flaky scrolling".
  [super setContentOffset:contentOffset animated:NO];
}
#endif

#if TARGET_OS_OSX

#pragma mark - Placeholder

- (NSAttributedString*)placeholderTextAttributedString
{
  if (self.placeholder == nil) {
    return nil;
  }
  NSMutableDictionary *placeholderAttributes = [self.typingAttributes mutableCopy];
  if (placeholderAttributes == nil) {
    placeholderAttributes = [NSMutableDictionary dictionary];
  }
  placeholderAttributes[NSForegroundColorAttributeName] = self.placeholderColor ?: defaultPlaceholderColor();
  placeholderAttributes[NSFontAttributeName] = self.font ?: defaultPlaceholderFont();
  return [[NSAttributedString alloc] initWithString:self.placeholder attributes:placeholderAttributes];
}

- (void)drawRect:(NSRect)dirtyRect
{
  [super drawRect:dirtyRect];
  
  if (self.text.length == 0 && self.placeholder) {
    NSAttributedString *attributedPlaceholderString = self.placeholderTextAttributedString;
    
    if (attributedPlaceholderString) {
      NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedPlaceholderString];
      NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:self.textContainer.containerSize];
      NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
      
      textContainer.lineFragmentPadding = self.textContainer.lineFragmentPadding;
      [layoutManager addTextContainer:textContainer];
      [textStorage addLayoutManager:layoutManager];
      
      NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
      [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:self.textContainerOrigin];
    }
  }
}

#pragma mark - Text Insets

- (void)setTextContainerInsets:(UIEdgeInsets)textContainerInsets
{
  // NSTextView             has a NSSize       textContainerInset  property
  // UITextview             has a UIEdgeInsets textContainerInset  property
  // RCTUITextView mac only has a UIEdgeInsets textContainerInsets property
  // UI/NSTextField do NOT have textContainerInset properties
  _textContainerInsets = textContainerInsets;
  super.textContainerInset = NSMakeSize(MIN(textContainerInsets.left, textContainerInsets.right), MIN(textContainerInsets.top, textContainerInsets.bottom));
}

#endif // TARGET_OS_OSX

#pragma mark - Layout

- (CGFloat)preferredMaxLayoutWidth
{
  // Returning size DOES contain `textContainerInset` (aka `padding`).
  return _preferredMaxLayoutWidth ?: self.placeholderSize.width;
}

- (CGSize)placeholderSize
{
#if !TARGET_OS_OSX
  UIEdgeInsets textContainerInset = self.textContainerInset;
#else
  UIEdgeInsets textContainerInset = self.textContainerInsets;
#endif
  NSString *placeholder = self.placeholder ?: @"";
  CGSize placeholderSize = [placeholder sizeWithAttributes:@{NSFontAttributeName: self.font ?: defaultPlaceholderFont()}];
#if !TARGET_OS_OSX
  placeholderSize = CGSizeMake(RCTCeilPixelValue(placeholderSize.width), RCTCeilPixelValue(placeholderSize.height));
#else
  CGFloat scale = self.window.backingScaleFactor;
  placeholderSize = CGSizeMake(RCTCeilPixelValue(placeholderSize.width, scale), RCTCeilPixelValue(placeholderSize.height, scale));
#endif
  placeholderSize.width += textContainerInset.left + textContainerInset.right;
  placeholderSize.height += textContainerInset.top + textContainerInset.bottom;
  // Returning size DOES contain `textContainerInset` (aka `padding`; as `sizeThatFits:` does).
  return placeholderSize;
}

- (CGSize)contentSize
{
#if !TARGET_OS_OSX
  CGSize contentSize = super.contentSize;
#else
  CGSize contentSize = super.intrinsicContentSize;
#endif
  CGSize placeholderSize = self.placeholderSize;
  // When a text input is empty, it actually displays a placehoder.
  // So, we have to consider `placeholderSize` as a minimum `contentSize`.
  // Returning size DOES contain `textContainerInset` (aka `padding`).
  return CGSizeMake(
    MAX(contentSize.width, placeholderSize.width),
    MAX(contentSize.height, placeholderSize.height));
}

#if !TARGET_OS_OSX
- (void)layoutSubviews
{
  [super layoutSubviews];

  CGRect textFrame = UIEdgeInsetsInsetRect(self.bounds, self.textContainerInset);
  CGFloat placeholderHeight = [_placeholderView sizeThatFits:textFrame.size].height;
  textFrame.size.height = MIN(placeholderHeight, textFrame.size.height);
  _placeholderView.frame = textFrame;
}
#endif

- (CGSize)intrinsicContentSize
{
  // Returning size DOES contain `textContainerInset` (aka `padding`).
  return [self sizeThatFits:CGSizeMake(self.preferredMaxLayoutWidth, INFINITY)];
}

- (CGSize)sizeThatFits:(CGSize)size
{
  // Returned fitting size depends on text size and placeholder size.
  CGSize textSize = [self fixedSizeThatFits:size];
  CGSize placeholderSize = self.placeholderSize;
  // Returning size DOES contain `textContainerInset` (aka `padding`).
  return CGSizeMake(MAX(textSize.width, placeholderSize.width), MAX(textSize.height, placeholderSize.height));
}

- (CGSize)fixedSizeThatFits:(CGSize)size
{
#if !TARGET_OS_OSX
  // UITextView on iOS 8 has a bug that automatically scrolls to the top
  // when calling `sizeThatFits:`. Use a copy so that self is not screwed up.
  static BOOL useCustomImplementation = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    useCustomImplementation = ![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9,0,0}];
  });

  if (!useCustomImplementation) {
    return [super sizeThatFits:size];
  }

  if (!_detachedTextView) {
    _detachedTextView = [UITextView new];
  }

  _detachedTextView.attributedText = self.attributedText;
  _detachedTextView.font = self.font;
  _detachedTextView.textContainerInset = self.textContainerInset;

  return [_detachedTextView sizeThatFits:size];
#else
  (void) [self.layoutManager glyphRangeForTextContainer:self.textContainer];
  NSRect rect = [self.layoutManager usedRectForTextContainer:self.textContainer];
  return CGSizeMake(MIN(rect.size.width, size.width), rect.size.height);
#endif
}

#pragma mark - Placeholder

- (void)invalidatePlaceholderVisibility
{
#if !TARGET_OS_OSX
  BOOL isVisible = _placeholder.length != 0 && self.text.length == 0;
  _placeholderView.hidden = !isVisible;
#else
  [self setNeedsDisplay:YES];
#endif
}

#if !TARGET_OS_OSX
- (void)deleteBackward {
  id<RCTBackedTextInputDelegate> textInputDelegate = [self textInputDelegate];
  if ([textInputDelegate textInputShouldHandleDeleteBackward:self]) {
    [super deleteBackward];
  }
}
#endif

@end
