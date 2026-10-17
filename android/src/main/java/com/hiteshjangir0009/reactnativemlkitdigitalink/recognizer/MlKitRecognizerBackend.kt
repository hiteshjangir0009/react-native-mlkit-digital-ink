package com.hiteshjangir0009.reactnativemlkitdigitalink.recognizer

import com.google.mlkit.common.MlKitException
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.vision.digitalink.DigitalInkRecognition
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModel
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModelIdentifier
import com.google.mlkit.vision.digitalink.DigitalInkRecognizer
import com.google.mlkit.vision.digitalink.DigitalInkRecognizerOptions
import com.google.mlkit.vision.digitalink.Ink
import kotlinx.coroutines.tasks.await
import java.util.concurrent.ConcurrentHashMap

/**
 * Wraps Google ML Kit's on-device Digital Ink Recognition SDK: per-language
 * model listing/download/delete, and recognition against a downloaded model.
 *
 * Thread-safety: [recognizers] is a [ConcurrentHashMap] guarded additionally
 * by [recognizerLock] for the compound get-or-create / close-and-remove
 * operations, so a `deleteModel()` call racing a `recognize()` call for the
 * same language can never leave a closed-but-still-cached recognizer behind
 * (a use-after-close crash) nor leak one.
 */
class MlKitRecognizerBackend {
  private val modelManager = RemoteModelManager.getInstance()
  private val recognizers = ConcurrentHashMap<String, DigitalInkRecognizer>()
  private val recognizerLock = Any()

  private fun modelIdentifierFor(languageTag: String): DigitalInkRecognitionModelIdentifier =
    try {
      DigitalInkRecognitionModelIdentifier.fromLanguageTag(languageTag)
        ?: throw UnsupportedLanguageException(languageTag)
    } catch (e: MlKitException) {
      throw UnsupportedLanguageException(languageTag)
    }

  private fun modelFor(languageTag: String): DigitalInkRecognitionModel =
    DigitalInkRecognitionModel.builder(modelIdentifierFor(languageTag)).build()

  suspend fun listAvailableModels(): List<Pair<String, Boolean>> {
    val identifiers = DigitalInkRecognitionModelIdentifier.allModelIdentifiers()
    return identifiers.map { identifier ->
      val model = DigitalInkRecognitionModel.builder(identifier).build()
      val downloaded = modelManager.isModelDownloaded(model).await()
      identifier.languageTag to downloaded
    }
  }

  suspend fun isModelDownloaded(languageTag: String): Boolean {
    val model = modelFor(languageTag)
    return modelManager.isModelDownloaded(model).await()
  }

  suspend fun downloadModel(languageTag: String) {
    val model = modelFor(languageTag)
    val conditions = DownloadConditions.Builder().build()
    try {
      modelManager.download(model, conditions).await()
    } catch (e: Exception) {
      throw ModelDownloadFailedException(languageTag, e)
    }
  }

  suspend fun deleteModel(languageTag: String) {
    val model = modelFor(languageTag)
    modelManager.deleteDownloadedModel(model).await()
    synchronized(recognizerLock) { recognizers.remove(languageTag)?.close() }
  }

  suspend fun recognize(ink: Ink, languageTag: String): RecognitionResultData {
    val model = modelFor(languageTag)
    if (!modelManager.isModelDownloaded(model).await()) {
      throw ModelNotDownloadedException(languageTag)
    }

    val recognizer =
      synchronized(recognizerLock) {
        recognizers.getOrPut(languageTag) {
          DigitalInkRecognition.getClient(DigitalInkRecognizerOptions.builder(model).build())
        }
      }

    val result = recognizer.recognize(ink).await()
    val candidates =
      result.candidates.map { candidate ->
        RecognitionCandidateResult(candidate.text, candidate.score ?: 0f)
      }
    return RecognitionResultData(candidates)
  }

  /** Closes every cached recognizer. Called from the module's lifecycle teardown. */
  fun closeAll() {
    synchronized(recognizerLock) {
      recognizers.values.forEach { it.close() }
      recognizers.clear()
    }
  }
}
