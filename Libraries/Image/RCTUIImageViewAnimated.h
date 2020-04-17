/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTAnimatedImage.h>
#import <React/RCTDefines.h>

#if TARGET_OS_OSX
@interface RCTUIImageViewAnimated : NSImageView
#else
@interface RCTUIImageViewAnimated : UIImageView
#endif // !TARGET_OS_OSX

@end
