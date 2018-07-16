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

#import "RCTBackedTextInputDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Just regular UITextView... but much better!
 */
@interface RCTUITextView : UITextView <RCTBackedTextInputViewProtocol>

- (instancetype)initWithFrame:(CGRect)frame textContainer:(nullable NSTextContainer *)textContainer NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@property (nonatomic, weak) id<RCTBackedTextInputDelegate> textInputDelegate;

#if !TARGET_OS_OSX
@property (nonatomic, assign, readonly) BOOL textWasPasted;
#else
@property (nonatomic, assign) BOOL textWasPasted;
#endif
@property (nonatomic, copy, nullable) NSString *placeholder;

@property (nonatomic, strong, nullable) UIColor *placeholderColor;

@property (nonatomic, assign) CGFloat preferredMaxLayoutWidth;

#if TARGET_OS_OSX
@property (nonatomic, strong, nullable) UIColor *selectionColor;
@property (nonatomic, assign) UIEdgeInsets textContainerInsets;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, copy, nullable) NSAttributedString *attributedText;
- (NSSize)sizeThatFits:(NSSize)size;
#endif // TARGET_OS_OSX

@end

NS_ASSUME_NONNULL_END
