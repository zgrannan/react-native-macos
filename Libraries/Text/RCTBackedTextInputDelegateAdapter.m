/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTBackedTextInputDelegateAdapter.h"

#pragma mark - RCTBackedTextFieldDelegateAdapter (for UITextField)

static void *TextFieldSelectionObservingContext = &TextFieldSelectionObservingContext;

@interface RCTBackedTextFieldDelegateAdapter ()
#if !TARGET_OS_OSX
<UITextFieldDelegate>
#else
<RCTUITextFieldDelegate>
#endif

@end

@implementation RCTBackedTextFieldDelegateAdapter {
  __weak UITextField<RCTBackedTextInputViewProtocol> *_backedTextInput;
  BOOL _textDidChangeIsComing;
#if !TARGET_OS_OSX
  UITextRange *_previousSelectedTextRange;
#else
  NSRange _previousSelectedTextRange;
#endif
}

- (instancetype)initWithTextField:(UITextField<RCTBackedTextInputViewProtocol> *)backedTextInput
{
  if (self = [super init]) {
    _backedTextInput = backedTextInput;
    backedTextInput.delegate = self;

#if !TARGET_OS_OSX
    [_backedTextInput addTarget:self action:@selector(textFieldDidChange) forControlEvents:UIControlEventEditingChanged];
    [_backedTextInput addTarget:self action:@selector(textFieldDidEndEditingOnExit) forControlEvents:UIControlEventEditingDidEndOnExit];
#endif
  }

  return self;
}

- (void)dealloc
{
#if !TARGET_OS_OSX
  [_backedTextInput removeTarget:self action:nil forControlEvents:UIControlEventEditingChanged];
  [_backedTextInput removeTarget:self action:nil forControlEvents:UIControlEventEditingDidEndOnExit];
#endif
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(__unused UITextField *)textField
{
  return [_backedTextInput.textInputDelegate textInputShouldBeginEditing];
}

- (void)textFieldDidBeginEditing:(__unused UITextField *)textField
{
  [_backedTextInput.textInputDelegate textInputDidBeginEditing];
}

- (BOOL)textFieldShouldEndEditing:(__unused UITextField *)textField
{
  return [_backedTextInput.textInputDelegate textInputShouldEndEditing];
}

- (void)textFieldDidEndEditing:(__unused UITextField *)textField
{
  if (_textDidChangeIsComing) {
    // iOS does't call `textViewDidChange:` delegate method if the change was happened because of autocorrection
    // which was triggered by losing focus. So, we call it manually.
    _textDidChangeIsComing = NO;
    [_backedTextInput.textInputDelegate textInputDidChange];
  }

  [_backedTextInput.textInputDelegate textInputDidEndEditing];
}

- (BOOL)textField:(__unused UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
  BOOL result = [_backedTextInput.textInputDelegate textInputShouldChangeTextInRange:range replacementText:string];
  if (result) {
    _textDidChangeIsComing = YES;
  }
  return result;
}

- (BOOL)textFieldShouldReturn:(__unused UITextField *)textField
{
  return [_backedTextInput.textInputDelegate textInputShouldReturn];
}

#pragma mark - UIControlEventEditing* Family Events

- (void)textFieldDidChange
{
  _textDidChangeIsComing = NO;
  [_backedTextInput.textInputDelegate textInputDidChange];

  // `selectedTextRangeWasSet` isn't triggered during typing.
  [self textFieldProbablyDidChangeSelection];
}

- (void)textFieldDidEndEditingOnExit
{
  [_backedTextInput.textInputDelegate textInputDidReturn];
}

#pragma mark - UIKeyboardInput (private UIKit protocol)

// This method allows us to detect a [Backspace] `keyPress`
// even when there is no more text in the `UITextField`.
- (BOOL)keyboardInputShouldDelete:(__unused UITextField *)textField
{
  [_backedTextInput.textInputDelegate textInputShouldChangeTextInRange:NSMakeRange(0, 0) replacementText:@""];
  return YES;
}

#pragma mark - Public Interface

#if !TARGET_OS_OSX
- (void)skipNextTextInputDidChangeSelectionEventWithTextRange:(UITextRange *)textRange
#else
- (void)skipNextTextInputDidChangeSelectionEventWithTextRange:(NSRange)textRange
#endif
{
  _previousSelectedTextRange = textRange;
}

- (void)selectedTextRangeWasSet
{
  [self textFieldProbablyDidChangeSelection];
}

#pragma mark - Generalization

- (void)textFieldProbablyDidChangeSelection
{
  if (RCTTextSelectionEqual([_backedTextInput selectedTextRange], _previousSelectedTextRange)) {
    return;
  }

  _previousSelectedTextRange = [_backedTextInput selectedTextRange];
  [_backedTextInput.textInputDelegate textInputDidChangeSelection];
}

#if TARGET_OS_OSX

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
  return [self textFieldShouldEndEditing:_backedTextInput];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
  BOOL commandHandled = NO;
  // enter/return
  if (commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
    [self textFieldDidEndEditingOnExit];
    commandHandled = YES;
    //backspace
  } else if (commandSelector == @selector(deleteBackward:)) {
    id<RCTBackedTextInputDelegate> textInputDelegate = [_backedTextInput textInputDelegate];
    if (textInputDelegate != nil && ![textInputDelegate textInputShouldHandleDeleteBackward:_backedTextInput]) {
      commandHandled = YES;
    } else {
      [self keyboardInputShouldDelete:_backedTextInput];
    }
    //deleteForward
  } else if (commandSelector == @selector(deleteForward:)) {
    id<RCTBackedTextInputDelegate> textInputDelegate = [_backedTextInput textInputDelegate];
    if (textInputDelegate != nil && ![textInputDelegate textInputShouldHandleDeleteForward:_backedTextInput]) {
      commandHandled = YES;
    } else {
      [self keyboardInputShouldDelete:_backedTextInput];
    }
    //paste
  } else if (commandSelector == @selector(paste:)) {
    _backedTextInput.textWasPasted = YES;
  }
  return commandHandled;
}

- (void)textFieldBeginEditing:(NSTextField *)textField
{
  [self textFieldDidBeginEditing:_backedTextInput];
}

- (void)textFieldDidChange:(NSTextField *)textField
{
  [self textFieldDidChange];
}

- (void)textFieldEndEditing:(NSTextField *)textField
{
  [self textFieldDidEndEditing:_backedTextInput];
}

- (void)textFieldDidChangeSelection:(NSTextField *)textField
{
  [self selectedTextRangeWasSet];
}
#endif // TARGET_OS_OSX

@end

#pragma mark - RCTBackedTextViewDelegateAdapter (for UITextView)

@interface RCTBackedTextViewDelegateAdapter () <UITextViewDelegate>
@end

@implementation RCTBackedTextViewDelegateAdapter {
#if !TARGET_OS_OSX
  __weak UITextView<RCTBackedTextInputViewProtocol> *_backedTextInput;
#else
  // TODO(tomun): NSTextView cannot be __weak
  __unsafe_unretained UITextView<RCTBackedTextInputViewProtocol> *_backedTextInput;
#endif
  BOOL _textDidChangeIsComing;
#if !TARGET_OS_OSX
  UITextRange *_previousSelectedTextRange;
#else
  NSRange _previousSelectedTextRange;
#endif
}

- (instancetype)initWithTextView:(UITextView<RCTBackedTextInputViewProtocol> *)backedTextInput
{
  if (self = [super init]) {
    _backedTextInput = backedTextInput;
    backedTextInput.delegate = self;
  }

  return self;
}

#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(__unused UITextView *)textView
{
  return [_backedTextInput.textInputDelegate textInputShouldBeginEditing];
}

- (void)textViewDidBeginEditing:(__unused UITextView *)textView
{
  [_backedTextInput.textInputDelegate textInputDidBeginEditing];
}

- (BOOL)textViewShouldEndEditing:(__unused UITextView *)textView
{
  return [_backedTextInput.textInputDelegate textInputShouldEndEditing];
}

- (void)textViewDidEndEditing:(__unused UITextView *)textView
{
  if (_textDidChangeIsComing) {
    // iOS does't call `textViewDidChange:` delegate method if the change was happened because of autocorrection
    // which was triggered by losing focus. So, we call it manually.
    _textDidChangeIsComing = NO;
    [_backedTextInput.textInputDelegate textInputDidChange];
  }

  [_backedTextInput.textInputDelegate textInputDidEndEditing];
}

- (BOOL)textView:(__unused UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  // Custom implementation of `textInputShouldReturn` and `textInputDidReturn` pair for `UITextView`.
  if (!_backedTextInput.textWasPasted && [text isEqualToString:@"\n"]) {
    if ([_backedTextInput.textInputDelegate textInputShouldReturn]) {
      [_backedTextInput.textInputDelegate textInputDidReturn];
#if !TARGET_OS_OSX
      [_backedTextInput endEditing:NO];
#else
      [[_backedTextInput window] endEditingFor:nil];
#endif
      return NO;
    }
  }

  BOOL result = [_backedTextInput.textInputDelegate textInputShouldChangeTextInRange:range replacementText:text];
  if (result) {
    _textDidChangeIsComing = YES;
  }
  return result;
}

- (void)textViewDidChange:(__unused UITextView *)textView
{
  _textDidChangeIsComing = NO;
  [_backedTextInput.textInputDelegate textInputDidChange];
}

#if !TARGET_OS_OSX

- (void)textViewDidChangeSelection:(__unused UITextView *)textView
{
  [self textViewProbablyDidChangeSelection];
}

#endif // !TARGET_OS_OSX

#if TARGET_OS_OSX

#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString
{
  return [self textView:textView shouldChangeTextInRange:affectedCharRange replacementText:replacementString];
}

- (void)textViewDidChangeSelection:(NSNotification *)notification
{
  [self textViewProbablyDidChangeSelection];
}

- (void)textDidBeginEditing:(NSNotification *)notification
{
  [self textViewDidBeginEditing:_backedTextInput];
}

- (void)textDidChange:(NSNotification *)notification
{
  [self textViewDidChange:_backedTextInput];
}

- (void)textDidEndEditing:(NSNotification *)notification
{
  [self textViewDidEndEditing:_backedTextInput];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
  BOOL commandHandled = NO;
  id<RCTBackedTextInputDelegate> textInputDelegate = [_backedTextInput textInputDelegate];
  // enter/return
  if (textInputDelegate.textInputShouldReturn && (commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertNewlineIgnoringFieldEditor:))) {
    [_backedTextInput.window makeFirstResponder:nil];
    commandHandled = YES;
    //backspace
  } else if (commandSelector == @selector(deleteBackward:)) {
    commandHandled = textInputDelegate != nil && ![textInputDelegate textInputShouldHandleDeleteBackward:_backedTextInput];
    //deleteForward
  } else if (commandSelector == @selector(deleteForward:)) {
    commandHandled = textInputDelegate != nil && ![textInputDelegate textInputShouldHandleDeleteForward:_backedTextInput];
  }

  return commandHandled;
}

#endif // TARGET_OS_OSX

#pragma mark - Public Interface

#if !TARGET_OS_OSX
- (void)skipNextTextInputDidChangeSelectionEventWithTextRange:(UITextRange *)textRange
#else
- (void)skipNextTextInputDidChangeSelectionEventWithTextRange:(NSRange)textRange
#endif
{
  _previousSelectedTextRange = textRange;
}

#pragma mark - Generalization

- (void)textViewProbablyDidChangeSelection
{
  if (RCTTextSelectionEqual([_backedTextInput selectedTextRange], _previousSelectedTextRange)) {
    return;
  }

  _previousSelectedTextRange = [_backedTextInput selectedTextRange];
  [_backedTextInput.textInputDelegate textInputDidChangeSelection];
}

@end
