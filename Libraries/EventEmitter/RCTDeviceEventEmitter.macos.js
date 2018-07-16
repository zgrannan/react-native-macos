/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule RCTDeviceEventEmitter
 * @flow
 */
'use strict';

const EventEmitter = require('EventEmitter');
const EventSubscriptionVendor = require('EventSubscriptionVendor');
const BatchedBridge = require('BatchedBridge');

import type EmitterSubscription from 'EmitterSubscription';

/**
 * Deprecated - subclass NativeEventEmitter to create granular event modules instead of
 * adding all event listeners directly to RCTDeviceEventEmitter.
 */
class RCTDeviceEventEmitter extends EventEmitter {

  sharedSubscriber: EventSubscriptionVendor;

  constructor() {
    const sharedSubscriber = new EventSubscriptionVendor();
    super(sharedSubscriber);
    this.sharedSubscriber = sharedSubscriber;
  }

  _nativeEventModule(eventType: ?string) {
    return null;
  }

  addListener(eventType: string, listener: Function, context: ?Object): EmitterSubscription {
    const eventModule = this._nativeEventModule(eventType);
    return eventModule ? eventModule.addListener(eventType, listener, context)
                       : super.addListener(eventType, listener, context);
  }

  removeAllListeners(eventType: ?string) {
    const eventModule = this._nativeEventModule(eventType);
    (eventModule && eventType) ? eventModule.removeAllListeners(eventType)
                               : super.removeAllListeners(eventType);
  }

  removeSubscription(subscription: EmitterSubscription) {
    if (subscription.emitter !== this) {
      subscription.emitter.removeSubscription(subscription);
    } else {
      super.removeSubscription(subscription);
    }
  }
}

RCTDeviceEventEmitter = new RCTDeviceEventEmitter();

BatchedBridge.registerCallableModule(
  'RCTDeviceEventEmitter',
  RCTDeviceEventEmitter
);

module.exports = RCTDeviceEventEmitter;
