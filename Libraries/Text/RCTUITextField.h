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

#import "RCTBackedTextInputViewProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Just regular UITextField... but much better!
 */
@interface RCTUITextField : UITextField <RCTBackedTextInputViewProtocol>

- (instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;

@property (nonatomic, weak) id<RCTBackedTextInputDelegate> textInputDelegate;

@property (nonatomic, assign) BOOL caretHidden;
#if !TARGET_OS_OSX
@property (nonatomic, readonly) BOOL textWasPasted;
#else
@property (nonatomic, assign) BOOL textWasPasted;
#endif
@property (nonatomic, strong, nullable) UIColor *placeholderColor;
@property (nonatomic, assign) UIEdgeInsets textContainerInset;
#if !TARGET_OS_OSX
@property (nonatomic, assign, getter=isEditable) BOOL editable;
#else
@property (assign, getter=isEditable) BOOL editable;
#endif
#if TARGET_OS_OSX
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, getter=isAutomaticTextReplacementEnabled) BOOL automaticTextReplacementEnabled;
@property (nonatomic, getter=isAutomaticSpellingCorrectionEnabled) BOOL automaticSpellingCorrectionEnabled;
@property (nonatomic, strong, nullable) UIColor *selectionColor;
@property (weak, nullable) id<RCTUITextFieldDelegate> delegate;
#endif // TARGET_OS_OSX

@end

NS_ASSUME_NONNULL_END
