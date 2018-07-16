/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTBridge+Cxx.h"
#import "RCTBridge+Private.h"
#import "RCTCxxBridge.h"
#import <objc/runtime.h>

@implementation RCTBridge (Cxx)

- (std::shared_ptr<facebook::react::Instance>)reactInstance {
	std::shared_ptr<facebook::react::Instance> instance;
	RCTBridge *batchBridge = [self batchedBridge];
	if ([batchBridge isKindOfClass:[RCTCxxBridge class]]) {
		RCTCxxBridge *cxxBridge = (RCTCxxBridge *)batchBridge;
		instance = [cxxBridge reactInstance];
	}
	return instance;
}

@end
