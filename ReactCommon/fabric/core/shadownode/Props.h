/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#include <folly/dynamic.h>

#include <fabric/core/primitives/ReactPrimitives.h>
#include <fabric/core/primitives/Sealable.h>
#include <fabric/debug/DebugStringConvertible.h>

namespace facebook {
namespace react {

class Props;

using SharedProps = std::shared_ptr<const Props>;

/*
 * Represents the most generic props object.
 */
class Props : public virtual Sealable, public virtual DebugStringConvertible {
 public:
  Props() = default;
  Props(const Props &sourceProps, const RawProps &rawProps);
  virtual ~Props() = default;

  const std::string nativeId;

#ifdef ANDROID
  const folly::dynamic rawProps = folly::dynamic::object();
#endif
};

} // namespace react
} // namespace facebook
