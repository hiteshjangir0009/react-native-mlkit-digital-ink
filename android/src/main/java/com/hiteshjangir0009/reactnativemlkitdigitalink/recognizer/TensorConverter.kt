package com.hiteshjangir0009.reactnativemlkitdigitalink.recognizer

import com.google.mlkit.vision.digitalink.Ink
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Turns a captured [Ink] into the exact-size input [ByteBuffer] a custom
 * TFLite model expects, and turns the model's raw float output back into
 * ranked [RecognitionCandidateResult]s — according to the app-supplied
 * [CustomModelTensorSpec] contract.
 *
 * This is intentionally conservative: every shape mismatch, empty ink, or
 * missing label list throws [InvalidConfigException] with a specific
 * message rather than letting a malformed buffer reach `Interpreter.run()`
 * (feeding TFLite a wrong-sized buffer is a hard native crash, not a
 * catchable Kotlin exception).
 */
object TensorConverter {

  fun buildInputBuffer(ink: Ink, spec: CustomModelTensorSpec): ByteBuffer {
    val points = ink.strokes.flatMap { it.points }
    if (points.isEmpty()) {
      throw InvalidConfigException("Ink has no points to feed to the custom model.")
    }

    return when (spec.preprocessing) {
      "rasterize" -> rasterize(ink, spec)
      "point-sequence" -> pointSequence(points, spec)
      else -> throw InvalidConfigException("Unknown preprocessing mode: ${spec.preprocessing}")
    }
  }

  fun elementCount(shape: List<Int>): Int {
    if (shape.isEmpty()) throw InvalidConfigException("Tensor shape must not be empty.")
    return shape.fold(1) { acc, dim ->
      if (dim <= 0) throw InvalidConfigException("Tensor shape dimensions must be positive, got $shape.")
      acc * dim
    }
  }

  private fun allocateFloatBuffer(elementCount: Int): ByteBuffer =
    ByteBuffer.allocateDirect(elementCount * 4).order(ByteOrder.nativeOrder())

  /** Rasterizes strokes onto a `height x width` grid (last two dims of [spec.inputShape]). */
  private fun rasterize(ink: Ink, spec: CustomModelTensorSpec): ByteBuffer {
    if (spec.inputShape.size < 2) {
      throw InvalidConfigException(
        "rasterize preprocessing requires an inputShape with at least 2 dimensions (height, width), got ${spec.inputShape}."
      )
    }
    val height = spec.inputShape[spec.inputShape.size - 2]
    val width = spec.inputShape[spec.inputShape.size - 1]
    val totalElements = elementCount(spec.inputShape)

    val minX = ink.strokes.flatMap { it.points }.minOf { it.x }
    val maxX = ink.strokes.flatMap { it.points }.maxOf { it.x }
    val minY = ink.strokes.flatMap { it.points }.minOf { it.y }
    val maxY = ink.strokes.flatMap { it.points }.maxOf { it.y }
    val spanX = (maxX - minX).takeIf { it > 0f } ?: 1f
    val spanY = (maxY - minY).takeIf { it > 0f } ?: 1f

    val grid = FloatArray(height * width)

    fun plot(px: Int, py: Int) {
      if (px in 0 until width && py in 0 until height) {
        grid[py * width + px] = 1f
      }
    }

    fun toGrid(x: Float, y: Float): Pair<Int, Int> {
      val gx = (((x - minX) / spanX) * (width - 1)).toInt()
      val gy = (((y - minY) / spanY) * (height - 1)).toInt()
      return gx to gy
    }

    for (stroke in ink.strokes) {
      var previous: Pair<Int, Int>? = null
      for (point in stroke.points) {
        val current = toGrid(point.x, point.y)
        if (previous == null) {
          plot(current.first, current.second)
        } else {
          drawLine(previous.first, previous.second, current.first, current.second, ::plot)
        }
        previous = current
      }
    }

    val buffer = allocateFloatBuffer(totalElements)
    // Broadcast the single-channel grid across any leading batch/channel
    // dimensions beyond height/width (e.g. [1, H, W, 1]) by repeating it.
    val repeats = totalElements / (height * width)
    repeat(repeats) {
      for (value in grid) buffer.putFloat(value)
    }
    buffer.rewind()
    return buffer
  }

  /** Bresenham's line algorithm — avoids gaps between fast-moving touch samples. */
  private fun drawLine(x0: Int, y0: Int, x1: Int, y1: Int, plot: (Int, Int) -> Unit) {
    var x = x0
    var y = y0
    val dx = kotlin.math.abs(x1 - x0)
    val dy = kotlin.math.abs(y1 - y0)
    val sx = if (x1 >= x0) 1 else -1
    val sy = if (y1 >= y0) 1 else -1
    var err = dx - dy
    plot(x, y)
    // Hard safety cap: a corrupt/huge coordinate pair could otherwise loop
    // for an extremely long time before converging.
    var steps = 0
    val maxSteps = dx + dy + 2
    while ((x != x1 || y != y1) && steps <= maxSteps) {
      val e2 = err * 2
      if (e2 > -dy) {
        err -= dy
        x += sx
      }
      if (e2 < dx) {
        err += dx
        y += sy
      }
      plot(x, y)
      steps += 1
    }
  }

  /** Flattens points into a padded/truncated `[maxPoints, channels]` sequence. */
  private fun pointSequence(points: List<Ink.Point>, spec: CustomModelTensorSpec): ByteBuffer {
    if (spec.inputShape.size < 2) {
      throw InvalidConfigException(
        "point-sequence preprocessing requires an inputShape with at least 2 dimensions (maxPoints, channels), got ${spec.inputShape}."
      )
    }
    val maxPoints = spec.inputShape[spec.inputShape.size - 2]
    val channels = spec.inputShape[spec.inputShape.size - 1]
    val totalElements = elementCount(spec.inputShape)

    val minX = points.minOf { it.x }
    val maxX = points.maxOf { it.x }
    val minY = points.minOf { it.y }
    val maxY = points.maxOf { it.y }
    val spanX = (maxX - minX).takeIf { it > 0f } ?: 1f
    val spanY = (maxY - minY).takeIf { it > 0f } ?: 1f

    val buffer = allocateFloatBuffer(totalElements)
    var written = 0
    for (point in points) {
      if (written >= maxPoints) break
      val x = if (spec.normalizePoints) (point.x - minX) / spanX else point.x
      val y = if (spec.normalizePoints) (point.y - minY) / spanY else point.y
      buffer.putFloat(x)
      if (channels >= 2) buffer.putFloat(y)
      if (channels >= 3) buffer.putFloat((point.timestamp ?: 0L).toFloat())
      for (extra in 3 until channels) buffer.putFloat(0f)
      written += 1
    }
    // Zero-pad any remaining rows up to maxPoints.
    while (written < maxPoints) {
      repeat(channels) { buffer.putFloat(0f) }
      written += 1
    }
    buffer.rewind()
    return buffer
  }

  fun decodeOutput(buffer: ByteBuffer, spec: CustomModelTensorSpec): RecognitionResultData {
    val labels =
      spec.labels
        ?: throw InvalidConfigException(
          "Custom model has no `labels` in its tensorSpec — cannot map output scores to text."
        )
    buffer.rewind()
    val totalElements = elementCount(spec.outputShape)
    if (totalElements != labels.size) {
      throw InvalidConfigException(
        "Custom model output has $totalElements elements but ${labels.size} labels were provided — they must match."
      )
    }

    val scores = FloatArray(totalElements)
    for (i in 0 until totalElements) {
      scores[i] = buffer.float
    }

    val candidates =
      labels.indices
        .map { i -> RecognitionCandidateResult(labels[i], scores[i]) }
        .sortedByDescending { it.score }

    return RecognitionResultData(candidates)
  }
}
