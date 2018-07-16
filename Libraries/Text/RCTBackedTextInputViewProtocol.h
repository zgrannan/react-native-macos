/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <React/RCTUIKit.h>
#import "RCTTextUIKit.h"

#if TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN
@protocol RCTUITextFieldDelegate <NSTextFieldDelegate>
@optional
- (BOOL)textField:(NSTextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;   // return NO to not change text
- (void)textFieldBeginEditing:(NSTextField *)textField;
- (void)textFieldDidChange:(NSTextField *)textField;
- (void)textFieldEndEditing:(NSTextField *)textField;
- (void)textFieldDidChangeSelection:(NSTextField *)textField;
@end
NS_ASSUME_NONNULL_END
#endif // TARGET_OS_OSX

@protocol RCTBackedTextInputDelegate;

#if !TARGET_OS_OSX
@protocol RCTBackedTextInputViewProtocol <UITextInput>
#else
@protocol RCTBackedTextInputViewProtocol
#endif

@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, strong, nullable) UIColor *textColor;
@property (nonatomic, copy, nullable) NSString *placeholder;
@property (nonatomic, strong, nullable) UIColor *placeholderColor;
#if !TARGET_OS_OSX
@property (nonatomic, assign, readonly) BOOL textWasPasted;
#else
@property (nonatomic, assign) BOOL textWasPasted;
#endif

@property (nonatomic, strong, nullable) UIFont *font;
@property (nonatomic, assign) UIEdgeInsets textContainerInset;
#if !TARGET_OS_OSX
@property (nonatomic, strong, nullable) UIView *inputAccessoryView;
#endif
@property (nonatomic, weak, nullable) id<RCTBackedTextInputDelegate> textInputDelegate;
@property (nonatomic, readonly) CGSize contentSize;

// This protocol disallows direct access to `selectedTextRange` property because
// unwise usage of it can break the `delegate` behavior. So, we always have to
// explicitly specify should `delegate` be notified about the change or not.
// If the change was initiated programmatically, we must NOT notify the delegate.
// If the change was a result of user actions (like typing or touches), we MUST notify the delegate.
#if !TARGET_OS_OSX
- (void)setSelectedTextRange:(nullable UITextRange *)selectedTextRange NS_UNAVAILABLE;
- (void)setSelectedTextRange:(nullable UITextRange *)selectedTextRange notifyDelegate:(BOOL)notifyDelegate;
#else
- (NSRange)selectedTextRange;
- (void)setSelectedTextRange:(NSRange)selectedTextRange NS_UNAVAILABLE;
- (void)setSelectedTextRange:(NSRange)selectedTextRange notifyDelegate:(BOOL)notifyDelegate;
#endif

#if TARGET_OS_OSX
// UITextInput method for OSX
- (CGSize)sizeThatFits:(CGSize)size;
#endif

@end
