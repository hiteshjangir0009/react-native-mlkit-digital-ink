import Foundation

/// Error codes shared with the JS side (`src/errors.ts`) and the Android
/// implementation — every rejection surfaced to JS carries one of these as
/// its `code`, regardless of which backend produced it.
enum DigitalInkErrorCode: String {
  case modelNotDownloaded = "E_MODEL_NOT_DOWNLOADED"
  case unsupportedLanguage = "E_UNSUPPORTED_LANGUAGE"
  case customModelNotRegistered = "E_CUSTOM_MODEL_NOT_REGISTERED"
  case modelFileNotFound = "E_MODEL_FILE_NOT_FOUND"
  case invalidInk = "E_INVALID_INK"
  case invalidConfig = "E_INVALID_CONFIG"
  case viewNotFound = "E_VIEW_NOT_FOUND"
  case downloadFailed = "E_DOWNLOAD_FAILED"
  case nativeException = "E_NATIVE_EXCEPTION"
}

struct DigitalInkError: Error {
  let code: DigitalInkErrorCode
  let message: String

  init(_ code: DigitalInkErrorCode, _ message: String) {
    self.code = code
    self.message = message
  }

  static func modelNotDownloaded(_ languageTag: String) -> DigitalInkError {
    DigitalInkError(
      .modelNotDownloaded,
      "Digital ink model for language \"\(languageTag)\" is not downloaded yet. Call downloadModel() first."
    )
  }

  static func unsupportedLanguage(_ languageTag: String) -> DigitalInkError {
    DigitalInkError(.unsupportedLanguage, "\"\(languageTag)\" is not a supported ML Kit digital ink language tag.")
  }

  static func customModelNotRegistered(_ modelId: String) -> DigitalInkError {
    DigitalInkError(
      .customModelNotRegistered,
      "No custom model registered under id \"\(modelId)\". Call registerCustomModel() first."
    )
  }

  static func modelFileNotFound(_ path: String) -> DigitalInkError {
    DigitalInkError(.modelFileNotFound, "Model file not found at path: \(path)")
  }

  static func invalidInk(_ message: String) -> DigitalInkError {
    DigitalInkError(.invalidInk, message)
  }

  static func invalidConfig(_ message: String) -> DigitalInkError {
    DigitalInkError(.invalidConfig, message)
  }

  static func viewNotFound(_ viewTag: NSNumber) -> DigitalInkError {
    DigitalInkError(.viewNotFound, "DigitalInkCanvasView with tag \(viewTag) was not found (unmounted?).")
  }

  static func downloadFailed(_ languageTag: String, _ underlying: Error?) -> DigitalInkError {
    let suffix = underlying.map { ": \($0.localizedDescription)" } ?? "."
    return DigitalInkError(.downloadFailed, "Failed to download model for \"\(languageTag)\"\(suffix)")
  }
}

/// Rejects a React Native promise with [error]'s code/message, carrying the
/// original error through as `NSError.userInfo[NSUnderlyingErrorKey]` where
/// available. Every bridge method funnels through this single path so the
/// error contract documented in `src/errors.ts` is never accidentally
/// bypassed by an ad-hoc reject call.
func rejectPromise(_ reject: @escaping (String?, String?, Error?) -> Void, with error: Error) {
  if let digitalInkError = error as? DigitalInkError {
    reject(digitalInkError.code.rawValue, digitalInkError.message, error)
  } else {
    reject(DigitalInkErrorCode.nativeException.rawValue, error.localizedDescription, error)
  }
}
