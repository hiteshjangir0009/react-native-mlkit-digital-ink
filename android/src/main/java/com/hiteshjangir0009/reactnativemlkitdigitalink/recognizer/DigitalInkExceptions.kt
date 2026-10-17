package com.hiteshjangir0009.reactnativemlkitdigitalink.recognizer

/**
 * Base for every typed failure this module can produce. [code] is sent
 * verbatim as the rejected promise's error code and MUST match one of the
 * `DigitalInkErrorCode` string literals the JS side (`src/errors.ts`) knows
 * how to map back into a typed `DigitalInkError`.
 */
sealed class DigitalInkException(val code: String, message: String) : Exception(message)

class UnsupportedLanguageException(languageTag: String) :
  DigitalInkException("E_UNSUPPORTED_LANGUAGE", "\"$languageTag\" is not a supported ML Kit digital ink language tag.")

class ModelNotDownloadedException(languageTag: String) :
  DigitalInkException(
    "E_MODEL_NOT_DOWNLOADED",
    "Digital ink model for language \"$languageTag\" is not downloaded yet. Call downloadModel() first."
  )

class ModelDownloadFailedException(languageTag: String, cause: Throwable?) :
  DigitalInkException(
    "E_DOWNLOAD_FAILED",
    "Failed to download model for \"$languageTag\"${cause?.message?.let { ": $it" } ?: "."}"
  )

class CustomModelNotRegisteredException(modelId: String) :
  DigitalInkException(
    "E_CUSTOM_MODEL_NOT_REGISTERED",
    "No custom model registered under id \"$modelId\". Call registerCustomModel() first."
  )

class ModelFileNotFoundException(modelPath: String) :
  DigitalInkException("E_MODEL_FILE_NOT_FOUND", "Model file not found at path: $modelPath")

class InvalidConfigException(message: String) : DigitalInkException("E_INVALID_CONFIG", message)

class ViewNotFoundException(viewTag: Double) :
  DigitalInkException("E_VIEW_NOT_FOUND", "DigitalInkCanvasView with tag $viewTag was not found (unmounted?).")
