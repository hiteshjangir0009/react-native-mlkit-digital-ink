package com.goaid.reactnativemlkitdigitalink

import com.facebook.react.bridge.ReactApplicationContext

class ReactNativeMlkitDigitalInkModule(reactContext: ReactApplicationContext) :
  NativeReactNativeMlkitDigitalInkSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeReactNativeMlkitDigitalInkSpec.NAME
  }
}
