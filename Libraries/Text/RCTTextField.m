/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTTextField.h"

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTFont.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>
#import <React/UIView+React.h>

#import "RCTBackedTextInputDelegate.h"
#import "RCTTextSelection.h"
#import "RCTUITextField.h"

@interface RCTTextField () <RCTBackedTextInputDelegate>

@end

@implementation RCTTextField
{
  RCTUITextField *_backedTextInput;
  BOOL _submitted;
  CGSize _previousContentSize;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  if (self = [super initWithBridge:bridge]) {
    // `blurOnSubmit` defaults to `true` for <TextInput multiline={false}> by design.
    _blurOnSubmit = YES;

    _backedTextInput = [[RCTUITextField alloc] initWithFrame:self.bounds];
    _backedTextInput.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backedTextInput.textInputDelegate = self;
    _backedTextInput.font = self.fontAttributes.font;

    [self addSubview:_backedTextInput];
  }

  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithFrame:(CGRect)frame)
RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (id<RCTBackedTextInputViewProtocol>)backedTextInputView
{
  return _backedTextInput;
}

- (void)sendKeyValueForString:(NSString *)string
{
  [_eventDispatcher sendTextEventWithType:RCTTextEventTypeKeyPress
                                 reactTag:self.reactTag
                                     text:nil
                                      key:string
                               eventCount:_nativeEventCount];
}

#pragma mark - Properties

#if TARGET_OS_OSX
- (void)setReactPaddingInsets:(UIEdgeInsets)reactPaddingInsets
{
  [super setReactPaddingInsets:reactPaddingInsets];
  // We apply `paddingInsets` as `backedTextInputView`'s `textContainerInsets` on mac.
  ((RCTUITextField*)self.backedTextInputView).textContainerInset = reactPaddingInsets;
  [self setNeedsLayout];
}

- (void)setReactBorderInsets:(UIEdgeInsets)reactBorderInsets
{
  [super setReactBorderInsets:reactBorderInsets];
  // We apply `borderInsets` as `backedTextInputView`'s layout offset on mac.
  ((RCTUITextField*)self.backedTextInputView).frame = UIEdgeInsetsInsetRect(self.bounds, reactBorderInsets);
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
  if (eventLag == 0 && ![text isEqualToString:self.text]) {
#if !TARGET_OS_OSX
    UITextRange *selection = _backedTextInput.selectedTextRange;
    NSInteger oldTextLength = _backedTextInput.text.length;

    _backedTextInput.text = text;

    if (selection.empty) {
      // maintain cursor position relative to the end of the old text
      NSInteger offsetStart = [_backedTextInput offsetFromPosition:_backedTextInput.beginningOfDocument toPosition:selection.start];
      NSInteger offsetFromEnd = oldTextLength - offsetStart;
      NSInteger newOffset = text.length - offsetFromEnd;
      UITextPosition *position = [_backedTextInput positionFromPosition:_backedTextInput.beginningOfDocument offset:newOffset];
      [_backedTextInput setSelectedTextRange:[_backedTextInput textRangeFromPosition:position toPosition:position]
                              notifyDelegate:YES];
    }
#else
    NSRange selection = _backedTextInput.currentEditor.selectedRange;
    NSInteger oldTextLength = _backedTextInput.text.length;
    
    _backedTextInput.text = text;
    
    if (selection.length == 0) {
      // maintain cursor position relative to the end of the old text
      NSInteger offsetStart = selection.location;
      NSInteger offsetFromEnd = oldTextLength - offsetStart;
      NSInteger newOffset = MAX(0, text.length - offsetFromEnd);
      [_backedTextInput setSelectedTextRange:NSMakeRange(newOffset, 0)
                              notifyDelegate:YES];
    }
#endif
  } else if (eventLag > RCTTextUpdateLagWarningThreshold) {
    RCTLogWarn(@"Native TextInput(%@) is %lld events ahead of JS - try to make your JS faster.", _backedTextInput.text, (long long)eventLag);
  }
}

#if 0 // TODO(tomun): refactored away by facebook, integrate into new classes

#pragma mark - Events

- (void)textFieldDidChange
{
  _nativeEventCount++;
  [_eventDispatcher sendTextEventWithType:RCTTextEventTypeChange
                                 reactTag:self.reactTag
                                     text:_textField.text
                                      key:nil
                               eventCount:_nativeEventCount];
#if !TARGET_OS_OSX
  // selectedTextRange observer isn't triggered when you type even though the
  // cursor position moves, so we send event again here.
  [self sendSelectionEvent];
#endif
}

- (void)textFieldEndEditing
{
  if (![_finalText isEqualToString:_textField.text]) {
    _finalText = nil;
    // iOS does't send event `UIControlEventEditingChanged` if the change was happened because of autocorrection
    // which was triggered by loosing focus. We assume that if `text` was changed in the middle of loosing focus process,
    // we did not receive that event. So, we call `textFieldDidChange` manually.
    [self textFieldDidChange];
  }
}

- (void)textFieldSubmitEditing
{
  _submitted = YES;
  [_eventDispatcher sendTextEventWithType:RCTTextEventTypeSubmit
                                 reactTag:self.reactTag
                                     text:_textField.text
                                      key:nil
                               eventCount:_nativeEventCount];
  
#if TARGET_OS_OSX
  if (_blurOnSubmit) {
    [self.window makeFirstResponder:nil];
  }
#endif
}

- (void)textFieldBeginEditing
{
  [_eventDispatcher sendTextEventWithType:RCTTextEventTypeFocus
                                 reactTag:self.reactTag
                                     text:_textField.text
                                      key:nil
                               eventCount:_nativeEventCount];

  dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_OSX
    if (self->_selectTextOnFocus) {
      [self->_textField selectAll:nil];
    }
#endif

    [self sendSelectionEvent];
  });
}

- (void)textFieldDidChangeSelection
{
  [self sendSelectionEvent];
}

#if !TARGET_OS_OSX
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(__unused UITextField *)textField
                        change:(__unused NSDictionary *)change
                       context:(__unused void *)context
{
  if ([keyPath isEqualToString:@"selectedTextRange"]) {
    [self textFieldDidChangeSelection];
  }
}
#endif

#endif // TODO(tomun): refactored away by facebook, integrate into new classes

#pragma mark - RCTBackedTextInputDelegate

- (BOOL)textInputShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)string
{
  // Only allow single keypresses for `onKeyPress`, pasted text will not be sent.
  if (!_backedTextInput.textWasPasted) {
    [self sendKeyValueForString:string];
  }

  if (_maxLength != nil && ![string isEqualToString:@"\n"]) { // Make sure forms can be submitted via return.
    NSUInteger allowedLength = _maxLength.integerValue - MIN(_maxLength.integerValue, _backedTextInput.text.length) + range.length;
    if (string.length > allowedLength) {
      if (string.length > 1) {
        // Truncate the input string so the result is exactly `maxLength`.
        NSString *limitedString = [string substringToIndex:allowedLength];
        NSMutableString *newString = _backedTextInput.text.mutableCopy;
        [newString replaceCharactersInRange:range withString:limitedString];
        _backedTextInput.text = newString;

        // Collapse selection at end of insert to match normal paste behavior.
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

  return YES;
}

- (void)textInputDidChange
{
  _nativeEventCount++;
  [_eventDispatcher sendTextEventWithType:RCTTextEventTypeChange
                                 reactTag:self.reactTag
                                     text:_backedTextInput.text
                                      key:nil
                               eventCount:_nativeEventCount];
}

#if TARGET_OS_OSX

#pragma mark - NSResponder chain

- (BOOL)canBecomeKeyView
{
	return NO; // Enclosed _textField can become the key view
}

#endif // TARGET_OS_OSX


@end
