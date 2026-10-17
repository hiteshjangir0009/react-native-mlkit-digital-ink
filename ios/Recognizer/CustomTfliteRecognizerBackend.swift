import Foundation
import TensorFlowLite

/// Pluggable second recognizer backend: runs a developer-supplied,
/// separately-trained TensorFlow Lite model (e.g. fine-tuned on clinical
/// handwriting) and returns results in the same `RecognitionResultData`
/// shape as `MlKitRecognizerBackend`.
///
/// Crash-safety notes:
///  - TensorFlowLiteSwift's `Interpreter` is explicitly documented as *not*
///    thread-safe. Every `invoke()` call is behind `NSLock` keyed per
///    interpreter instance — two overlapping `recognize()` calls against the
///    same custom model would otherwise corrupt the interpreter's internal
///    tensor buffers (a native crash, not a catchable Swift error).
///  - Registering a model under an id that's already registered safely
///    drops the previous `Interpreter` first (ARC deallocates it), so there
///    is never more than one loaded interpreter per modelId.
final class CustomTfliteRecognizerBackend {
  private final class Registered {
    let interpreter: Interpreter
    let spec: CustomModelTensorSpec
    let lock = NSLock()
    init(interpreter: Interpreter, spec: CustomModelTensorSpec) {
      self.interpreter = interpreter
      self.spec = spec
    }
  }

  private var models: [String: Registered] = [:]
  private let modelsLock = NSLock()

  func register(_ registration: CustomModelRegistrationData) throws {
    guard FileManager.default.fileExists(atPath: registration.modelPath) else {
      throw DigitalInkError.modelFileNotFound(registration.modelPath)
    }

    var options = Interpreter.Options()
    options.threadCount = 2

    let interpreter: Interpreter
    do {
      interpreter = try Interpreter(modelPath: registration.modelPath, options: options)
      try interpreter.allocateTensors()
    } catch {
      throw DigitalInkError.invalidConfig(
        "Failed to load custom model \"\(registration.modelId)\": \(error.localizedDescription)"
      )
    }

    try validateTensorShapes(interpreter: interpreter, registration: registration)

    modelsLock.lock()
    models[registration.modelId] = Registered(interpreter: interpreter, spec: registration.tensorSpec)
    modelsLock.unlock()
  }

  func unregister(modelId: String) {
    modelsLock.lock()
    models.removeValue(forKey: modelId)
    modelsLock.unlock()
  }

  func recognize(ink: DigitalInkInk, modelId: String) throws -> RecognitionResultData {
    modelsLock.lock()
    let registered = models[modelId]
    modelsLock.unlock()
    guard let registered else {
      throw DigitalInkError.customModelNotRegistered(modelId)
    }

    let inputData = try TensorConverter.buildInputData(ink: ink, spec: registered.spec)
    let outputElementCount = try TensorConverter.elementCount(registered.spec.outputShape)

    registered.lock.lock()
    defer { registered.lock.unlock() }

    _ = try registered.interpreter.copy(inputData, toInputAt: 0)
    try registered.interpreter.invoke()
    let outputTensor = try registered.interpreter.output(at: 0)

    guard outputTensor.data.count >= outputElementCount * 4 else {
      throw DigitalInkError.invalidConfig(
        "Custom model \"\(modelId)\" produced \(outputTensor.data.count) output bytes, " +
          "fewer than the \(outputElementCount * 4) implied by outputShape."
      )
    }

    return try TensorConverter.decodeOutput(data: outputTensor.data, spec: registered.spec)
  }

  func closeAll() {
    modelsLock.lock()
    models.removeAll()
    modelsLock.unlock()
  }

  private func validateTensorShapes(interpreter: Interpreter, registration: CustomModelRegistrationData) throws {
    let actualInput = try interpreter.input(at: 0).shape.dimensions
    let expectedInputElements = try TensorConverter.elementCount(registration.tensorSpec.inputShape)
    let actualInputElements = actualInput.reduce(1, *)
    guard expectedInputElements == actualInputElements else {
      throw DigitalInkError.invalidConfig(
        "Custom model \"\(registration.modelId)\" input tensor has \(actualInputElements) elements " +
          "(shape \(actualInput)) but tensorSpec.inputShape \(registration.tensorSpec.inputShape) " +
          "implies \(expectedInputElements)."
      )
    }

    let actualOutput = try interpreter.output(at: 0).shape.dimensions
    let expectedOutputElements = try TensorConverter.elementCount(registration.tensorSpec.outputShape)
    let actualOutputElements = actualOutput.reduce(1, *)
    guard expectedOutputElements == actualOutputElements else {
      throw DigitalInkError.invalidConfig(
        "Custom model \"\(registration.modelId)\" output tensor has \(actualOutputElements) elements " +
          "(shape \(actualOutput)) but tensorSpec.outputShape \(registration.tensorSpec.outputShape) " +
          "implies \(expectedOutputElements)."
      )
    }
  }
}
