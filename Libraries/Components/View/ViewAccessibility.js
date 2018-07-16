/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule ViewAccessibility
 * @flow
 */
'use strict';

const PropTypes = require('prop-types');
const createStrictShapeTypeChecker = require('createStrictShapeTypeChecker');

const AccessibilityNodeInfoPropType = createStrictShapeTypeChecker({
  clickable: PropTypes.bool,
});

export type AccessibilityTrait =
  'none' |
  'button' |
  'link' |
  'header' |
  'search' |
  'image' |
  'selected' |
  'plays' |
  'key' |
  'text' |
  'summary' |
  'disabled' |
  'frequentUpdates' |
  'startsMedia' |
  'adjustable' |
  'allowsDirectInteraction' |
  'pageTurn' |
  'group' |
  'list';

export type AccessibilityComponentType =
  'none' |
  'button' |
  'radiobutton_checked' |
  'radiobutton_unchecked';
  
export type AccessibilityNodeInfoProp = {
  clickable: bool,
};

module.exports = {
  AccessibilityTraits: [
    'none',
    'button',
    'link',
    'header',
    'search',
    'image',
    'selected',
    'plays',
    'key',
    'text',
    'summary',
    'disabled',
    'frequentUpdates',
    'startsMedia',
    'adjustable',
    'allowsDirectInteraction',
    'pageTurn',
    'group',
    'list',
  ],
  AccessibilityComponentTypes: [
    'none',
    'button',
    'radiobutton_checked',
    'radiobutton_unchecked',
  ],
  AccessibilityNodeInfoPropType
};