package com.goaid.reactnativemlkitdigitalink.recognizer

import com.google.mlkit.vision.digitalink.Ink
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import org.tensorflow.lite.Interpreter

/**
 * Pluggable second recognizer backend: runs a developer-supplied,
 * separately-trained TensorFlow Lite model (e.g. fine-tuned on clinical
 * handwriting) and returns results in the same [RecognitionResultData]
 * shape as [MlKitRecognizerBackend], so callers can treat both engines
 * interchangeably.
 *
 * Crash-safety notes:
 *  - `Interpreter` is documented as NOT safe for concurrent `run()` calls —
 *    every invocation is behind `synchronized(interpreter)`. Two overlapping
 *    `recognize()` calls against the same custom model would otherwise
 *    corrupt the interpreter's internal tensor buffers (a native crash, not
 *    a catchable exception).
 *  - Registering a model with the same id twice safely closes the previous
 *    interpreter first, so there is never more than one open interpreter
 *    per modelId leaking native memory.
 */
class CustomTfliteRecognizerBackend {
  private data class RegisteredModel(val interpreter: Interpreter, val spec: CustomModelTensorSpec)

  private val models = ConcurrentHashMap<String, RegisteredModel>()
  private val modelsLock = Any()

  fun register(registration: CustomModelRegistrationData) {
    val file = File(registration.modelPath)
    if (!file.exists() || !file.isFile) {
      throw ModelFileNotFoundException(registration.modelPath)
    }

    val options = Interpreter.Options().apply { numThreads = 2 }
    val interpreter =
      try {
        Interpreter(file, options)
      } catch (e: Exception) {
        // TFLite throws IllegalArgumentException on a corrupt/invalid
        // FlatBuffer — normalize it into our typed error contract.
        throw InvalidConfigException("Failed to load custom model \"${registration.modelId}\": ${e.message}")
      }

    validateTensorShapes(interpreter, registration)

    synchronized(modelsLock) {
      // Replace-safe: close any previous interpreter registered under this
      // id before overwriting it, so we never leak a native interpreter.
      models[registration.modelId]?.interpreter?.close()
      models[registration.modelId] = RegisteredModel(interpreter, registration.tensorSpec)
    }
  }

  fun unregister(modelId: String) {
    synchronized(modelsLock) { models.remove(modelId)?.interpreter?.close() }
  }

  fun recognize(ink: Ink, modelId: String): RecognitionResultData {
    val registered = models[modelId] ?: throw CustomModelNotRegisteredException(modelId)

    val inputBuffer = TensorConverter.buildInputBuffer(ink, registered.spec)
    val outputElementCount = TensorConverter.elementCount(registered.spec.outputShape)
    val outputBuffer =
      ByteBuffer.allocateDirect(outputElementCount * 4).order(ByteOrder.nativeOrder())

    // Interpreter.run() is not thread-safe for concurrent invocations on the
    // same instance — serialize access per interpreter.
    synchronized(registered.interpreter) {
      registered.interpreter.run(inputBuffer, outputBuffer)
    }

    return TensorConverter.decodeOutput(outputBuffer, registered.spec)
  }

  fun closeAll() {
    synchronized(modelsLock) {
      models.values.forEach { it.interpreter.close() }
      models.clear()
    }
  }

  private fun validateTensorShapes(interpreter: Interpreter, registration: CustomModelRegistrationData) {
    val actualInputShape = interpreter.getInputTensor(0).shape().toList()
    val expectedInputElements = TensorConverter.elementCount(registration.tensorSpec.inputShape)
    val actualInputElements = actualInputShape.fold(1) { acc, dim -> acc * dim }
    if (expectedInputElements != actualInputElements) {
      interpreter.close()
      throw InvalidConfigException(
        "Custom model \"${registration.modelId}\" input tensor has $actualInputElements elements " +
          "(shape $actualInputShape) but tensorSpec.inputShape ${registration.tensorSpec.inputShape} " +
          "implies $expectedInputElements."
      )
    }

    val actualOutputShape = interpreter.getOutputTensor(0).shape().toList()
    val expectedOutputElements = TensorConverter.elementCount(registration.tensorSpec.outputShape)
    val actualOutputElements = actualOutputShape.fold(1) { acc, dim -> acc * dim }
    if (expectedOutputElements != actualOutputElements) {
      interpreter.close()
      throw InvalidConfigException(
        "Custom model \"${registration.modelId}\" output tensor has $actualOutputElements elements " +
          "(shape $actualOutputShape) but tensorSpec.outputShape ${registration.tensorSpec.outputShape} " +
          "implies $expectedOutputElements."
      )
    }
  }
}
