package com.hiteshjangir0009.reactnativemlkitdigitalink

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager
import com.hiteshjangir0009.reactnativemlkitdigitalink.view.DigitalInkCanvasViewManager

class ReactNativeMlkitDigitalInkPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == ReactNativeMlkitDigitalInkModule.NAME) {
      ReactNativeMlkitDigitalInkModule(reactContext)
    } else {
      null
    }
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
    listOf(DigitalInkCanvasViewManager())

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      ReactNativeMlkitDigitalInkModule.NAME to ReactModuleInfo(
        name = ReactNativeMlkitDigitalInkModule.NAME,
        className = ReactNativeMlkitDigitalInkModule.NAME,
        canOverrideExistingModule = false,
        needsEagerInit = false,
        isCxxModule = false,
        isTurboModule = true
      )
    )
  }
}
