package com.goaid.reactnativemlkitdigitalink.model

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.google.mlkit.vision.digitalink.Ink
import com.goaid.reactnativemlkitdigitalink.recognizer.RecognitionCandidateResult
import com.goaid.reactnativemlkitdigitalink.recognizer.RecognitionResultData
import com.goaid.reactnativemlkitdigitalink.view.CapturedStroke

/**
 * Converts between the JS-bridge representation (ReadableMap/WritableMap, as
 * produced by codegen's flattened `NativeInk`/`NativeRecognitionResult`
 * shapes) and both ML Kit's `Ink` type and our own plain `RecognitionResultData`.
 *
 * Every parse function here throws [IllegalArgumentException] on malformed
 * input rather than returning a half-built object or crashing on a null
 * dereference — callers (the TurboModule methods) catch this uniformly and
 * reject the promise with `E_INVALID_INK` / `E_INVALID_CONFIG`.
 */
object InkMapper {

  /** Defensive ceiling mirrored from the JS side (`convert.ts`). */
  private const val MAX_TOTAL_POINTS = 50_000

  fun inkFromReadableMap(map: ReadableMap?): Ink {
    requireNotNull(map) { "Ink payload is null." }
    val strokesArray: ReadableArray =
      map.getArray("strokes") ?: throw IllegalArgumentException("Ink.strokes is missing.")
    if (strokesArray.size() == 0) {
      throw IllegalArgumentException("Ink must contain at least one stroke.")
    }

    val inkBuilder = Ink.builder()
    var totalPoints = 0

    for (strokeIndex in 0 until strokesArray.size()) {
      val strokeMap =
        strokesArray.getMap(strokeIndex)
          ?: throw IllegalArgumentException("Stroke at index $strokeIndex is null.")
      val pointsArray: ReadableArray =
        strokeMap.getArray("points")
          ?: throw IllegalArgumentException("Stroke at index $strokeIndex has no points.")

      val strokeBuilder = Ink.Stroke.builder()
      for (pointIndex in 0 until pointsArray.size()) {
        val pointMap =
          pointsArray.getMap(pointIndex)
            ?: throw IllegalArgumentException(
              "Point at index $pointIndex in stroke $strokeIndex is null."
            )
        if (!pointMap.hasKey("x") || !pointMap.hasKey("y") || !pointMap.hasKey("t")) {
          throw IllegalArgumentException(
            "Point at index $pointIndex in stroke $strokeIndex is missing x/y/t."
          )
        }
        val x = pointMap.getDouble("x").toFloat()
        val y = pointMap.getDouble("y").toFloat()
        val t = pointMap.getDouble("t").toLong()
        strokeBuilder.addPoint(Ink.Point.create(x, y, t))

        totalPoints += 1
        if (totalPoints > MAX_TOTAL_POINTS) {
          throw IllegalArgumentException(
            "Ink exceeds the maximum of $MAX_TOTAL_POINTS total points."
          )
        }
      }
      inkBuilder.addStroke(strokeBuilder.build())
    }

    if (totalPoints == 0) {
      throw IllegalArgumentException("Ink has no points.")
    }

    return inkBuilder.build()
  }

  /** Converts the Fabric view's own captured-stroke snapshot directly to the
   * JS-bridge `NativeInk` shape, without going through ML Kit's `Ink` type
   * (the view has no reason to depend on the ML Kit SDK at all). */
  fun capturedStrokesToWritableMap(strokes: List<CapturedStroke>): WritableMap {
    val map = Arguments.createMap()
    val strokesArray: WritableArray = Arguments.createArray()
    for (stroke in strokes) {
      val strokeMap = Arguments.createMap()
      val pointsArray: WritableArray = Arguments.createArray()
      for (point in stroke.points) {
        val pointMap = Arguments.createMap()
        pointMap.putDouble("x", point.x.toDouble())
        pointMap.putDouble("y", point.y.toDouble())
        pointMap.putDouble("t", point.t.toDouble())
        pointsArray.pushMap(pointMap)
      }
      strokeMap.putArray("points", pointsArray)
      strokesArray.pushMap(strokeMap)
    }
    map.putArray("strokes", strokesArray)
    return map
  }

  fun resultToWritableMap(result: RecognitionResultData): WritableMap {
    val map = Arguments.createMap()
    val candidatesArray: WritableArray = Arguments.createArray()
    for (candidate in result.candidates) {
      val candidateMap = Arguments.createMap()
      candidateMap.putString("text", candidate.text)
      candidateMap.putDouble(
        "score",
        if (candidate.score.isFinite()) candidate.score.toDouble() else 0.0
      )
      candidatesArray.pushMap(candidateMap)
    }
    map.putArray("candidates", candidatesArray)
    return map
  }
}
