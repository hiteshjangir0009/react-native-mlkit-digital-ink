import Foundation
import React

/// Implements every `NativeReactNativeMlkitDigitalInkSpec` method using
/// plain Foundation types — the ObjC++ trampoline (`ReactNativeMlkitDigitalInk.mm`)
/// flattens codegen's C++ structs into `NSDictionary`/`NSArray` before
/// calling in here, so this file never has to deal with the generated
/// `JS::...::NativeXxx` C++ types directly.
///
/// Crash-safety: every method dispatches onto `queue` (never blocking the
/// caller's thread) and wraps its body in `do/catch` — a Swift error thrown
/// anywhere in the call graph (ML Kit, TFLite, or `InkMapper` parsing) is
/// turned into a promise rejection via `rejectPromise(_:with:)`, never an
/// uncaught exception. Bridged NSDictionary/NSArray values are always read
/// with `as?`/optional-binding, never force-unwrapped or force-cast.
@objc(DigitalInkRecognizerModuleImpl)
public final class DigitalInkRecognizerModuleImpl: NSObject {
  private let queue = DispatchQueue(label: "com.hiteshjangir0009.digitalink.recognizer", qos: .userInitiated)
  private let mlkitBackend = MlKitRecognizerBackend()
  private let customBackend = CustomTfliteRecognizerBackend()

  public override init() {
    super.init()
  }

  // MARK: - ML Kit model management

  @objc public func listAvailableModels(
    _ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      resolve(InkMapper.dictionary(from: self.mlkitBackend.listAvailableModels()) as NSArray)
    }
  }

  @objc public func isModelDownloaded(
    _ languageTag: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      do {
        resolve(try self.mlkitBackend.isModelDownloaded(languageTag: languageTag))
      } catch {
        rejectPromise(reject, with: error)
      }
    }
  }

  @objc public func downloadModel(
    _ languageTag: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      self.mlkitBackend.downloadModel(languageTag: languageTag) { result in
        switch result {
        case .success: resolve(nil)
        case .failure(let error): rejectPromise(reject, with: error)
        }
      }
    }
  }

  @objc public func deleteModel(
    _ languageTag: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      self.mlkitBackend.deleteModel(languageTag: languageTag) { result in
        switch result {
        case .success: resolve(nil)
        case .failure(let error): rejectPromise(reject, with: error)
        }
      }
    }
  }

  // MARK: - custom TFLite model management

  @objc public func registerCustomModel(
    _ registration: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      do {
        try self.customBackend.register(InkMapper.customModelRegistration(from: registration))
        resolve(nil)
      } catch {
        rejectPromise(reject, with: error)
      }
    }
  }

  @objc public func unregisterCustomModel(
    _ modelId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      self.customBackend.unregister(modelId: modelId)
      resolve(nil)
    }
  }

  // MARK: - recognition

  @objc public func recognize(
    _ ink: NSDictionary,
    config: NSDictionary,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      do {
        let parsedInk = try InkMapper.ink(from: ink)
        let kind = try InkMapper.recognizerKind(from: config)
        switch kind {
        case "mlkit":
          guard let languageTag = config["languageTag"] as? String else {
            throw DigitalInkError.invalidConfig("mlkit config requires languageTag.")
          }
          self.mlkitBackend.recognize(ink: parsedInk, languageTag: languageTag) { result in
            switch result {
            case .success(let data): resolve(InkMapper.dictionary(from: data))
            case .failure(let error): rejectPromise(reject, with: error)
            }
          }
        case "custom":
          guard let modelId = config["modelId"] as? String else {
            throw DigitalInkError.invalidConfig("custom config requires modelId.")
          }
          let result = try self.customBackend.recognize(ink: parsedInk, modelId: modelId)
          resolve(InkMapper.dictionary(from: result))
        default:
          throw DigitalInkError.invalidConfig("Unknown recognizer kind: \(kind)")
        }
      } catch {
        rejectPromise(reject, with: error)
      }
    }
  }

  // MARK: - imperative canvas operations, resolved by React tag

  @objc public func clearCanvas(
    _ viewTag: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    withView(viewTag, reject: reject) { view in
      view.clear()
      resolve(nil)
    }
  }

  @objc public func undoLastStroke(
    _ viewTag: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    withView(viewTag, reject: reject) { view in
      view.undoLastStroke()
      resolve(nil)
    }
  }

  @objc public func getInk(
    _ viewTag: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    withView(viewTag, reject: reject) { view in
      resolve(InkMapper.dictionary(from: view.snapshot()))
    }
  }

  private func withView(
    _ viewTag: NSNumber, reject: @escaping RCTPromiseRejectBlock, body: @escaping (DigitalInkCanvasView) -> Void
  ) {
    DispatchQueue.main.async {
      guard let view = DigitalInkCanvasViewRegistry.shared.view(forTag: viewTag.intValue) else {
        let error = DigitalInkError.viewNotFound(viewTag)
        reject(error.code.rawValue, error.message, error)
        return
      }
      body(view)
    }
  }

  @objc public func invalidate() {
    mlkitBackend.closeAll()
    customBackend.closeAll()
  }

  deinit {
    invalidate()
  }
}
