package com.hiteshjangir0009.reactnativemlkitdigitalink.recognizer

/** Plain, backend-agnostic result shape both [MlKitRecognizerBackend] and
 * [CustomTfliteRecognizerBackend] return, so the TurboModule method doesn't
 * need to care which engine produced it. */
data class RecognitionResultData(val candidates: List<RecognitionCandidateResult>)

data class RecognitionCandidateResult(val text: String, val score: Float)
