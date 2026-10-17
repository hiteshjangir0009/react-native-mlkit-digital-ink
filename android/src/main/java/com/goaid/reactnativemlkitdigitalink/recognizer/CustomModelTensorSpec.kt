package com.goaid.reactnativemlkitdigitalink.recognizer

/** Mirrors the JS `CustomModelTensorSpec` type (see `src/types.ts`). */
data class CustomModelTensorSpec(
  val inputShape: List<Int>,
  val outputShape: List<Int>,
  val preprocessing: String, // "rasterize" | "point-sequence"
  val labels: List<String>?,
  val normalizePoints: Boolean
)

data class CustomModelRegistrationData(
  val modelId: String,
  val modelPath: String,
  val tensorSpec: CustomModelTensorSpec
)
