/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTTextView.h"

#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTFont.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>
#import <React/UIView+React.h>

#import "RCTShadowText.h"
#import "RCTText.h"
#import "RCTTextSelection.h"

@interface RCTTextView () <RCTBackedTextInputDelegate>

@end

@implementation RCTTextView
{
#if TARGET_OS_OSX
  UIScrollView *_scrollView;
#endif
  RCTUITextView *_backedTextInput;
  RCTText *_richTextView;
  NSAttributedString *_pendingAttributedText;

  BOOL _blockTextShouldChange;
  BOOL _nativeUpdatesInFlight;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  RCTAssertParam(bridge);

  if (self = [super initWithBridge:bridge]) {
    // `blurOnSubmit` defaults to `false` for <TextInput multiline={true}> by design.
    _blurOnSubmit = NO;

    _backedTextInput = [[RCTUITextView alloc] initWithFrame:self.bounds];
    _backedTextInput.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backedTextInput.backgroundColor = [UIColor clearColor];
    _backedTextInput.textColor = [UIColor blackColor];
    // This line actually removes 5pt (default value) left and right padding in UITextView.
    _backedTextInput.textContainer.lineFragmentPadding = 0;
#if !TARGET_OS_OSX
#if !TARGET_OS_TV
    _backedTextInput.scrollsToTop = NO;
#endif
    _backedTextInput.scrollEnabled = YES;
#else
    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.drawsBackground = NO;
    _scrollView.borderType = NSNoBorder;
    _scrollView.hasHorizontalRuler = NO;
    _scrollView.hasVerticalRuler = NO;
    _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    _backedTextInput.verticallyResizable = YES;
    _backedTextInput.horizontallyResizable = YES;
    _backedTextInput.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    _backedTextInput.textContainer.widthTracksTextView = YES;
#endif
#if !TARGET_OS_OSX
    _backedTextInput.scrollEnabled = YES;
#endif
    _backedTextInput.textInputDelegate = self;
    _backedTextInput.font = self.fontAttributes.font;

#if !TARGET_OS_OSX
    [self addSubview:_backedTextInput];
#else
    _scrollView.documentView = _backedTextInput;
    _scrollView.contentView.postsBoundsChangedNotifications = YES;
    [self addSubview:_scrollView];
    
    // a register for those notifications on the content view.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boundDidChange:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:_scrollView.contentView];
    
#endif
  }
  return self;
}

#if TARGET_OS_OSX
- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#endif

RCT_NOT_IMPLEMENTED(- (instancetype)initWithFrame:(CGRect)frame)
RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (id<RCTBackedTextInputViewProtocol>)backedTextInputView
{
  return _backedTextInput;
}

#pragma mark - RCTComponent

- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)index
{
  [super insertReactSubview:subview atIndex:index];

  if ([subview isKindOfClass:[RCTText class]]) {
    if (_richTextView) {
      RCTLogError(@"Tried to insert a second <Text> into <TextInput> - there can only be one.");
    }
    _richTextView = (RCTText *)subview;

    // If this <TextInput> is in rich text editing mode, and the child <Text> node providing rich text
    // styling has a backgroundColor, then the attributedText produced by the child <Text> node will have an
    // NSBackgroundColor attribute. We need to forward this attribute to the text view manually because the text view
    // always has a clear background color in `initWithBridge:`.
    //
    // TODO: This should be removed when the related hack in -performPendingTextUpdate is removed.
    if (subview.backgroundColor) {
      NSMutableDictionary<NSString *, id> *attrs = [_backedTextInput.typingAttributes mutableCopy];
      attrs[NSBackgroundColorAttributeName] = subview.backgroundColor;
      _backedTextInput.typingAttributes = attrs;
    }

    [self performTextUpdate];
  }
}

- (void)removeReactSubview:(UIView *)subview
{
  [super removeReactSubview:subview];
  if (_richTextView == subview) {
    _richTextView = nil;
    [self performTextUpdate];
  }
}

- (void)didUpdateReactSubviews
{
  // Do nothing, as we don't allow non-text subviews.
}

#pragma mark - Routine

- (void)setMostRecentEventCount:(NSInteger)mostRecentEventCount
{
  _mostRecentEventCount = mostRecentEventCount;

  // Props are set after uiBlockToAmendWithShadowViewRegistry, which means that
  // at the time performTextUpdate is called, _mostRecentEventCount will be
  // behind _eventCount, with the result that performPendingTextUpdate will do
  // nothing. For that reason we call it again here after mostRecentEventCount
  // has been set.
  [self performPendingTextUpdate];
}

- (void)performTextUpdate
{
  if (_richTextView) {
    _pendingAttributedText = _richTextView.textStorage;
    [self performPendingTextUpdate];
  } else if (!self.text) {
    _backedTextInput.attributedText = nil;
  }
}

static NSAttributedString *removeReactTagFromString(NSAttributedString *string)
{
  if (string.length == 0) {
    return string;
  } else {
    NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
    [mutableString removeAttribute:RCTReactTagAttributeName range:NSMakeRange(0, mutableString.length)];
    return mutableString;
  }
}

- (void)performPendingTextUpdate
{
  if (!_pendingAttributedText || _mostRecentEventCount < _nativeEventCount || _nativeUpdatesInFlight) {
    return;
  }

  // The underlying <Text> node that produces _pendingAttributedText has a react tag attribute on it that causes the
  // -isEqualToAttributedString: comparison below to spuriously fail. We don't want that comparison to fail unless it
  // needs to because when the comparison fails, we end up setting attributedText on the text view, which clears
  // autocomplete state for CKJ text input.
  //
  // TODO: Kill this after we finish passing all style/attribute info into JS.
  _pendingAttributedText = removeReactTagFromString(_pendingAttributedText);

  if ([_backedTextInput.attributedText isEqualToAttributedString:_pendingAttributedText]) {
    _pendingAttributedText = nil; // Don't try again.
    return;
  }

  // When we update the attributed text, there might be pending autocorrections
  // that will get accepted by default. In order for this to not garble our text,
  // we temporarily block all textShouldChange events so they are not applied.
  _blockTextShouldChange = YES;

#if !TARGET_OS_OSX
  UITextRange *selection = _backedTextInput.selectedTextRange;
#else
  NSRange selection = _backedTextInput.selectedRange;
#endif
  NSInteger oldTextLength = _backedTextInput.attributedText.length;

  _backedTextInput.attributedText = _pendingAttributedText;
  [self setPredictedText:_pendingAttributedText.string];
  _pendingAttributedText = nil;
  
#if !TARGET_OS_OSX
  if (selection.empty) {
    // maintain cursor position relative to the end of the old text
    NSInteger start = [_backedTextInput offsetFromPosition:_backedTextInput.beginningOfDocument toPosition:selection.start];
    NSInteger offsetFromEnd = oldTextLength - start;
    NSInteger newOffset = _backedTextInput.attributedText.length - offsetFromEnd;
    UITextPosition *position = [_backedTextInput positionFromPosition:_backedTextInput.beginningOfDocument offset:newOffset];
    [_backedTextInput setSelectedTextRange:[_backedTextInput textRangeFromPosition:position toPosition:position]
                            notifyDelegate:YES];
  }
  
  [_backedTextInput layoutIfNeeded];
#else
  if (selection.length == 0) {
    // maintain cursor position relative to the end of the old text
    NSInteger start = selection.location;
    NSInteger offsetFromEnd = oldTextLength - start;
    NSInteger newOffset = MAX(0, _backedTextInput.attributedText.length - offsetFromEnd);
    [_backedTextInput setSelectedTextRange:NSMakeRange(newOffset, 0)
                            notifyDelegate:YES];
  }
  [_backedTextInput layoutSubtreeIfNeeded];
#endif

  [self invalidateContentSize];

  _blockTextShouldChange = NO;
}

#pragma mark - Properties

- (UIFont *)font
{
  return _backedTextInput.font;
}

- (void)setFont:(UIFont *)font
{
  _backedTextInput.font = font;
  [self setNeedsLayout];
}

#if TARGET_OS_OSX
- (void)setReactPaddingInsets:(UIEdgeInsets)reactPaddingInsets
{
  [super setReactPaddingInsets:reactPaddingInsets];
  // We apply `paddingInsets` as `backedTextInputView`'s `textContainerInsets` on mac.
  ((RCTUITextView*)self.backedTextInputView).textContainerInsets = reactPaddingInsets;
  [self setNeedsLayout];
}

- (void)setReactBorderInsets:(UIEdgeInsets)reactBorderInsets
{
  [super setReactBorderInsets:reactBorderInsets];
  // We apply `borderInsets` as `_scrollView` layout offset on mac.
  _scrollView.frame = UIEdgeInsetsInsetRect(self.frame, reactBorderInsets);
  [self setNeedsLayout];
}
#endif // TARGET_OS_OSX

- (NSString *)text
{
  return _backedTextInput.text;
}

- (void)setText:(NSString *)text
{
  NSInteger eventLag = _nativeEventCount - _mostRecentEventCount;
  if (eventLag == 0 && ![text isEqualToString:_backedTextInput.text]) {
#if !TARGET_OS_OSX
    UITextRange *selection = _backedTextInput.selectedTextRange;
#else
    NSRange selection = _backedTextInput.selectedRange;
#endif
    NSInteger oldTextLength = _backedTextInput.text.length;

    [self setPredictedText:text];
    _backedTextInput.text = text;
#if !TARGET_OS_OSX
    if (selection.empty) {
      // maintain cursor position relative to the end of the old text
      NSInteger start = [_backedTextInput offsetFromPosition:_backedTextInput.beginningOfDocument toPosition:selection.start];
      NSInteger offsetFromEnd = oldTextLength - start;
      NSInteger newOffset = text.length - offsetFromEnd;
      UITextPosition *position = [_backedTextInput positionFromPosition:_backedTextInput.beginningOfDocument offset:newOffset];
      [_backedTextInput setSelectedTextRange:[_backedTextInput textRangeFromPosition:position toPosition:position]
                              notifyDelegate:YES];
    }
#else
    if (selection.length == 0) {
      // maintain cursor position relative to the end of the old text
      NSInteger start = selection.location;
      NSInteger offsetFromEnd = oldTextLength - start;
      NSInteger newOffset = _backedTextInput.attributedText.length - offsetFromEnd;
      [_backedTextInput setSelectedTextRange:NSMakeRange(newOffset, 0)
                              notifyDelegate:YES];
    }
#endif

    [self invalidateContentSize];
  } else if (eventLag > RCTTextUpdateLagWarningThreshold) {
    RCTLogWarn(@"Native TextInput(%@) is %lld events ahead of JS - try to make your JS faster.", self.text, (long long)eventLag);
  }
}

#pragma mark - RCTBackedTextInputDelegate

- (BOOL)textInputShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  if (!_backedTextInput.textWasPasted) {
    [_eventDispatcher sendTextEventWithType:RCTTextEventTypeKeyPress
                                   reactTag:self.reactTag
                                       text:nil
                                        key:text
                                 eventCount:_nativeEventCount];
  }

  // So we need to track that there is a native update in flight just in case JS manages to come back around and update
  // things /before/ UITextView can update itself asynchronously.  If there is a native update in flight, we defer the
  // JS update when it comes in and apply the deferred update once textViewDidChange fires with the native update applied.
  if (_blockTextShouldChange) {
    return NO;
  }

  if (_maxLength) {
    NSUInteger allowedLength = _maxLength.integerValue - _backedTextInput.text.length + range.length;
    if (text.length > allowedLength) {
      // If we typed/pasted more than one character, limit the text inputted
      if (text.length > 1) {
        // Truncate the input string so the result is exactly maxLength
        NSString *limitedString = [text substringToIndex:allowedLength];
        NSMutableString *newString = _backedTextInput.text.mutableCopy;
        [newString replaceCharactersInRange:range withString:limitedString];
        _backedTextInput.text = newString;
        [self setPredictedText:newString];

        // Collapse selection at end of insert to match normal paste behavior
#if !TARGET_OS_OSX
        UITextPosition *insertEnd = [_backedTextInput positionFromPosition:_backedTextInput.beginningOfDocument
                                                            offset:(range.location + allowedLength)];
        [_backedTextInput setSelectedTextRange:[_backedTextInput textRangeFromPosition:insertEnd toPosition:insertEnd]
                                notifyDelegate:YES];
#else
        [_backedTextInput setSelectedTextRange:NSMakeRange(range.location + allowedLength, 0)
                                notifyDelegate:YES];
#endif

        [self textInputDidChange];
      }
      return NO;
    }
  }

  _nativeUpdatesInFlight = YES;

  if (range.location + range.length > [[self predictedText] length]) {
    // predictedText got out of sync in a bad way, so let's just force sync it.  Haven't been able to repro this, but
    // it's causing a real crash here: #6523822
    [self setPredictedText:_backedTextInput.text];
   
  }
  NSString *predictedText = [self predictedText];
  NSString *previousText = [predictedText substringWithRange:range];
  if (predictedText) {
    [self setPredictedText:[predictedText stringByReplacingCharactersInRange:range withString:text]];
  } else {
    [self setPredictedText:text];
  }

  if (_onTextInput) {
    _onTextInput(@{
      @"text": text,
      @"previousText": previousText ?: @"",
      @"range": @{
        @"start": @(range.location),
        @"end": @(range.location + range.length)
      },
      @"eventCount": @(_nativeEventCount),
    });
  }

  return YES;
}

static BOOL findMismatch(NSString *first, NSString *second, NSRange *firstRange, NSRange *secondRange)
{
  NSInteger firstMismatch = -1;
  for (NSUInteger ii = 0; ii < MAX(first.length, second.length); ii++) {
    if (ii >= first.length || ii >= second.length || [first characterAtIndex:ii] != [second characterAtIndex:ii]) {
      firstMismatch = ii;
      break;
    }
  }

  if (firstMismatch == -1) {
    return NO;
  }

  NSUInteger ii = second.length;
  NSUInteger lastMismatch = first.length;
  while (ii > firstMismatch && lastMismatch > firstMismatch) {
    if ([first characterAtIndex:(lastMismatch - 1)] != [second characterAtIndex:(ii - 1)]) {
      break;
    }
    ii--;
    lastMismatch--;
  }

  *firstRange = NSMakeRange(firstMismatch, lastMismatch - firstMismatch);
  *secondRange = NSMakeRange(firstMismatch, ii - firstMismatch);
  return YES;
}

- (void)textInputDidChange
{
  [self invalidateContentSize];

  // Detect when _backedTextInput updates happend that didn't invoke `shouldChangeTextInRange`
  // (e.g. typing simplified chinese in pinyin will insert and remove spaces without
  // calling shouldChangeTextInRange).  This will cause JS to get out of sync so we
  // update the mismatched range.
  NSRange currentRange;
  NSRange predictionRange;
  if (findMismatch(_backedTextInput.text, [self predictedText], &currentRange, &predictionRange)) {
    NSString *replacement = [_backedTextInput.text substringWithRange:currentRange];
    [self textInputShouldChangeTextInRange:predictionRange replacementText:replacement];
    // JS will assume the selection changed based on the location of our shouldChangeTextInRange, so reset it.
    [self textInputDidChangeSelection];
    [self setPredictedText:_backedTextInput.text];
  }

  _nativeUpdatesInFlight = NO;
  _nativeEventCount++;

  if (!self.reactTag || !_onChange) {
    return;
  }

  _onChange(@{
    @"text": self.text,
    @"target": self.reactTag,
    @"eventCount": @(_nativeEventCount),
  });
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (_onScroll) {
    CGPoint contentOffset = scrollView.contentOffset;
    CGSize contentSize = scrollView.contentSize;
    CGSize size = scrollView.bounds.size;
    UIEdgeInsets contentInset = scrollView.contentInset;

    _onScroll(@{
      @"contentOffset": @{
        @"x": @(contentOffset.x),
        @"y": @(contentOffset.y)
      },
      @"contentInset": @{
        @"top": @(contentInset.top),
        @"left": @(contentInset.left),
        @"bottom": @(contentInset.bottom),
        @"right": @(contentInset.right)
      },
      @"contentSize": @{
        @"width": @(contentSize.width),
        @"height": @(contentSize.height)
      },
      @"layoutMeasurement": @{
        @"width": @(size.width),
        @"height": @(size.height)
      },
      @"zoomScale": @(scrollView.zoomScale ?: 1),
    });
  }
}
  
#if TARGET_OS_OSX
  
#pragma mark - Notification handling
  
- (void)boundDidChange:(NSNotification*)NSNotification
{
  [self scrollViewDidScroll:_scrollView];
}
  
#pragma mark - NSResponder chain
  
- (BOOL)acceptsFirstResponder
{
  return _backedTextInput.acceptsFirstResponder;
}
  
#endif

@end
