package com.goaid.reactnativemlkitdigitalink

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.UiThreadUtil
import com.goaid.reactnativemlkitdigitalink.model.InkMapper
import com.goaid.reactnativemlkitdigitalink.recognizer.CustomModelRegistrationData
import com.goaid.reactnativemlkitdigitalink.recognizer.CustomModelTensorSpec
import com.goaid.reactnativemlkitdigitalink.recognizer.CustomTfliteRecognizerBackend
import com.goaid.reactnativemlkitdigitalink.recognizer.DigitalInkException
import com.goaid.reactnativemlkitdigitalink.recognizer.InvalidConfigException
import com.goaid.reactnativemlkitdigitalink.recognizer.MlKitRecognizerBackend
import com.goaid.reactnativemlkitdigitalink.recognizer.ViewNotFoundException
import com.goaid.reactnativemlkitdigitalink.view.DigitalInkCanvasView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ReactNativeMlkitDigitalInkModule(reactContext: ReactApplicationContext) :
  NativeReactNativeMlkitDigitalInkSpec(reactContext) {

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
  private val mlKitBackend = MlKitRecognizerBackend()
  private val customBackend = CustomTfliteRecognizerBackend()

  // --- ML Kit model management -------------------------------------------------

  override fun listAvailableModels(promise: Promise) {
    runGuarded(promise) {
      val models = mlKitBackend.listAvailableModels()
      val array: WritableArray = Arguments.createArray()
      for ((languageTag, isDownloaded) in models) {
        array.pushMap(
          Arguments.createMap().apply {
            putString("languageTag", languageTag)
            putBoolean("isDownloaded", isDownloaded)
          }
        )
      }
      array
    }
  }

  override fun isModelDownloaded(languageTag: String, promise: Promise) {
    runGuarded(promise) { mlKitBackend.isModelDownloaded(languageTag) }
  }

  override fun downloadModel(languageTag: String, promise: Promise) {
    runGuarded(promise) {
      mlKitBackend.downloadModel(languageTag)
      null
    }
  }

  override fun deleteModel(languageTag: String, promise: Promise) {
    runGuarded(promise) {
      mlKitBackend.deleteModel(languageTag)
      null
    }
  }

  // --- custom TFLite model management -------------------------------------------

  override fun registerCustomModel(registration: ReadableMap, promise: Promise) {
    runGuarded(promise) {
      customBackend.register(parseRegistration(registration))
      null
    }
  }

  override fun unregisterCustomModel(modelId: String, promise: Promise) {
    runGuarded(promise) {
      customBackend.unregister(modelId)
      null
    }
  }

  // --- recognition ---------------------------------------------------------------

  override fun recognize(ink: ReadableMap, config: ReadableMap, promise: Promise) {
    runGuarded(promise) {
      val parsedInk = InkMapper.inkFromReadableMap(ink)
      val kind = config.getString("kind") ?: throw InvalidConfigException("config.kind is missing.")
      val result =
        when (kind) {
          "mlkit" -> {
            val languageTag =
              config.getString("languageTag")
                ?: throw InvalidConfigException("mlkit config requires languageTag.")
            mlKitBackend.recognize(parsedInk, languageTag)
          }
          "custom" -> {
            val modelId =
              config.getString("modelId") ?: throw InvalidConfigException("custom config requires modelId.")
            customBackend.recognize(parsedInk, modelId)
          }
          else -> throw InvalidConfigException("Unknown recognizer kind: $kind")
        }
      InkMapper.resultToWritableMap(result)
    }
  }

  // --- imperative canvas operations, resolved by React tag -----------------------

  override fun clearCanvas(viewTag: Double, promise: Promise) {
    withViewOnUi(viewTag, promise) { view ->
      view.clear()
      null
    }
  }

  override fun undoLastStroke(viewTag: Double, promise: Promise) {
    withViewOnUi(viewTag, promise) { view ->
      view.undoLastStroke()
      null
    }
  }

  override fun getInk(viewTag: Double, promise: Promise) {
    withViewOnUi(viewTag, promise) { view -> InkMapper.capturedStrokesToWritableMap(view.snapshot()) }
  }

  private fun parseRegistration(map: ReadableMap): CustomModelRegistrationData {
    val modelId = map.getString("modelId") ?: throw InvalidConfigException("registration.modelId is missing.")
    val modelPath = map.getString("modelPath") ?: throw InvalidConfigException("registration.modelPath is missing.")
    val tensorSpecMap =
      map.getMap("tensorSpec") ?: throw InvalidConfigException("registration.tensorSpec is missing.")

    val inputShapeArray =
      tensorSpecMap.getArray("inputShape")
        ?: throw InvalidConfigException("tensorSpec.inputShape is missing.")
    val outputShapeArray =
      tensorSpecMap.getArray("outputShape")
        ?: throw InvalidConfigException("tensorSpec.outputShape is missing.")
    val preprocessing =
      tensorSpecMap.getString("preprocessing")
        ?: throw InvalidConfigException("tensorSpec.preprocessing is missing.")

    val inputShape = (0 until inputShapeArray.size()).map { inputShapeArray.getInt(it) }
    val outputShape = (0 until outputShapeArray.size()).map { outputShapeArray.getInt(it) }
    val labels =
      if (tensorSpecMap.hasKey("labels") && !tensorSpecMap.isNull("labels")) {
        val labelsArray = tensorSpecMap.getArray("labels")
        (0 until (labelsArray?.size() ?: 0)).map { labelsArray!!.getString(it) ?: "" }
      } else {
        null
      }
    val normalizePoints =
      tensorSpecMap.hasKey("normalizePoints") && !tensorSpecMap.isNull("normalizePoints") &&
        tensorSpecMap.getBoolean("normalizePoints")

    return CustomModelRegistrationData(
      modelId = modelId,
      modelPath = modelPath,
      tensorSpec =
        CustomModelTensorSpec(
          inputShape = inputShape,
          outputShape = outputShape,
          preprocessing = preprocessing,
          labels = labels,
          normalizePoints = normalizePoints
        )
    )
  }

  /** Runs [block] on [Dispatchers.Default], resolves/rejects [promise] on the
   * main thread. Every Exception — ML Kit's, TFLite's, or a parsing
   * IllegalArgumentException/our own [DigitalInkException] — is caught here;
   * none can propagate out of a TurboModule method and crash the app. */
  private fun runGuarded(promise: Promise, block: suspend () -> Any?) {
    scope.launch {
      try {
        val result = block()
        withContext(Dispatchers.Main) { promise.resolve(result) }
      } catch (e: DigitalInkException) {
        withContext(Dispatchers.Main) { promise.reject(e.code, e.message, e) }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) { promise.reject("E_NATIVE_EXCEPTION", e.message, e) }
      }
    }
  }

  private fun withViewOnUi(viewTag: Double, promise: Promise, block: (DigitalInkCanvasView) -> Any?) {
    UiThreadUtil.runOnUiThread {
      try {
        val view = DigitalInkCanvasView.findByReactTag(reactApplicationContext, viewTag.toInt())
        if (view == null) {
          val error = ViewNotFoundException(viewTag)
          promise.reject(error.code, error.message, error)
          return@runOnUiThread
        }
        promise.resolve(block(view))
      } catch (e: Exception) {
        promise.reject("E_NATIVE_EXCEPTION", e.message, e)
      }
    }
  }

  override fun invalidate() {
    super.invalidate()
    // Cancel every in-flight coroutine so no stray ML Kit/TFLite callback
    // touches a dead bridge/promise after the module is torn down.
    scope.cancel()
    mlKitBackend.closeAll()
    customBackend.closeAll()
  }

  companion object {
    const val NAME = NativeReactNativeMlkitDigitalInkSpec.NAME
  }
}
