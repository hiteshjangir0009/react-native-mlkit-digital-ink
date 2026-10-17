import Foundation
import MLKitCommon
import MLKitDigitalInkRecognition

/// Wraps Google ML Kit's on-device Digital Ink Recognition SDK for iOS:
/// per-language model listing/download/delete, and recognition against a
/// downloaded model.
///
/// Every public method here is only ever called from the module's dedicated
/// serial background queue (`DigitalInkRecognizerModuleImpl`'s `queue`),
/// never concurrently with itself — `lock` guards the `recognizers` cache
/// defensively regardless, so a `deleteModel` racing a `recognize` call for
/// the same language can never leave a stale cached recognizer behind.
final class MlKitRecognizerBackend {
  private var recognizers: [String: DigitalInkRecognizer] = [:]
  private let lock = NSLock()

  private func modelIdentifier(for languageTag: String) throws -> DigitalInkRecognitionModelIdentifier {
    guard let identifier = try? DigitalInkRecognitionModelIdentifier.from(languageTag: languageTag) else {
      throw DigitalInkError.unsupportedLanguage(languageTag)
    }
    return identifier
  }

  private func model(for languageTag: String) throws -> DigitalInkRecognitionModel {
    DigitalInkRecognitionModel(modelIdentifier: try modelIdentifier(for: languageTag))
  }

  func listAvailableModels() -> [(languageTag: String, isDownloaded: Bool)] {
    let manager = ModelManager.modelManager()
    return DigitalInkRecognitionModelIdentifier.allModelIdentifiers().map { identifier in
      let model = DigitalInkRecognitionModel(modelIdentifier: identifier)
      return (identifier.languageTag, manager.isModelDownloaded(model))
    }
  }

  func isModelDownloaded(languageTag: String) throws -> Bool {
    let model = try model(for: languageTag)
    return ModelManager.modelManager().isModelDownloaded(model)
  }

  /// Downloads the model and resolves once ML Kit reports success/failure
  /// via `NotificationCenter`. Those notifications are global (not scoped to
  /// one download call), so the observer explicitly filters by model
  /// identity — without this, two concurrent `downloadModel()` calls for
  /// different languages would cross-fire each other's completion.
  func downloadModel(languageTag: String, completion: @escaping (Result<Void, Error>) -> Void) {
    let model: DigitalInkRecognitionModel
    do {
      model = try self.model(for: languageTag)
    } catch {
      completion(.failure(error))
      return
    }

    let center = NotificationCenter.default
    var successObserver: NSObjectProtocol?
    var failureObserver: NSObjectProtocol?

    func cleanup() {
      if let o = successObserver { center.removeObserver(o) }
      if let o = failureObserver { center.removeObserver(o) }
    }

    successObserver = center.addObserver(
      forName: .mlkitModelDownloadDidSucceed, object: nil, queue: nil
    ) { note in
      guard let downloaded = note.userInfo?[ModelDownloadUserInfoKey.remoteModel] as? DigitalInkRecognitionModel,
        downloaded.modelIdentifier == model.modelIdentifier
      else { return }
      cleanup()
      completion(.success(()))
    }
    failureObserver = center.addObserver(
      forName: .mlkitModelDownloadDidFail, object: nil, queue: nil
    ) { note in
      guard let failed = note.userInfo?[ModelDownloadUserInfoKey.remoteModel] as? DigitalInkRecognitionModel,
        failed.modelIdentifier == model.modelIdentifier
      else { return }
      cleanup()
      let underlying = note.userInfo?[ModelDownloadUserInfoKey.error] as? Error
      completion(.failure(DigitalInkError.downloadFailed(languageTag, underlying)))
    }

    let conditions = ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: false)
    _ = ModelManager.modelManager().download(model, conditions: conditions)
  }

  func deleteModel(languageTag: String, completion: @escaping (Result<Void, Error>) -> Void) {
    let model: DigitalInkRecognitionModel
    do {
      model = try self.model(for: languageTag)
    } catch {
      completion(.failure(error))
      return
    }
    ModelManager.modelManager().deleteDownloadedModel(model) { [weak self] error in
      if let error {
        completion(.failure(error))
        return
      }
      self?.lock.lock()
      self?.recognizers.removeValue(forKey: languageTag)
      self?.lock.unlock()
      completion(.success(()))
    }
  }

  func recognize(
    ink: DigitalInkInk, languageTag: String, completion: @escaping (Result<RecognitionResultData, Error>) -> Void
  ) {
    let model: DigitalInkRecognitionModel
    do {
      model = try self.model(for: languageTag)
    } catch {
      completion(.failure(error))
      return
    }

    guard ModelManager.modelManager().isModelDownloaded(model) else {
      completion(.failure(DigitalInkError.modelNotDownloaded(languageTag)))
      return
    }

    lock.lock()
    let recognizer: DigitalInkRecognizer
    if let existing = recognizers[languageTag] {
      recognizer = existing
    } else {
      recognizer = DigitalInkRecognizer.digitalInkRecognizer(options: DigitalInkRecognizerOptions(model: model))
      recognizers[languageTag] = recognizer
    }
    lock.unlock()

    let mlkInk = MlKitInkConverter.toMlKitInk(ink)
    recognizer.recognize(ink: mlkInk) { result, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard let result else {
        completion(.failure(DigitalInkError(.nativeException, "ML Kit returned no result and no error.")))
        return
      }
      let candidates = result.candidates.map { candidate in
        RecognitionCandidateResult(text: candidate.text, score: candidate.score?.floatValue ?? 0)
      }
      completion(.success(RecognitionResultData(candidates: candidates)))
    }
  }

  /// No explicit "close" API exists on `DigitalInkRecognizer` in the iOS SDK
  /// (unlike Android) — dropping all strong references here is sufficient
  /// for ARC to deallocate them.
  func closeAll() {
    lock.lock()
    recognizers.removeAll()
    lock.unlock()
  }
}

/// Converts our plain, SDK-agnostic `DigitalInkInk` into ML Kit's own
/// `Ink`/`Stroke`/`StrokePoint` object graph.
enum MlKitInkConverter {
  static func toMlKitInk(_ ink: DigitalInkInk) -> Ink {
    let strokes = ink.strokes.map { stroke -> Stroke in
      let points = stroke.points.map { point in
        StrokePoint(x: Float(point.x), y: Float(point.y), t: Int(point.t))
      }
      return Stroke(points: points)
    }
    return Ink(strokes: strokes)
  }
}
