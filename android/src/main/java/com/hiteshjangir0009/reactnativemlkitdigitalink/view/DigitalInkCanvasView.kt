package com.hiteshjangir0009.reactnativemlkitdigitalink.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerHelper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Captures handwriting strokes via raw touch events and renders them.
 *
 * Thread-safety: [strokes] is a [CopyOnWriteArrayList] because [snapshot] /
 * [clear] / [undoLastStroke] are called from the TurboModule's background
 * coroutine (see `DigitalInkRecognizerModule.getInk`) while touch events
 * mutate [currentStroke] on the UI thread — a copy-on-write list means a
 * concurrent snapshot read can never throw `ConcurrentModificationException`
 * or observe a half-mutated list.
 *
 * [onDetachedFromWindow] clears all buffers so no stroke/point data is
 * retained by a view instance once it's unmounted (or recycled by Fabric).
 */
class DigitalInkCanvasView(context: Context) : View(context) {

  private val strokes = CopyOnWriteArrayList<MutableList<CapturedPoint>>()

  @Volatile private var currentStroke: MutableList<CapturedPoint>? = null

  /** Defensive cap applied per-stroke; overridable via the `maxPointsPerStroke` prop. */
  var maxPointsPerStroke: Int = DEFAULT_MAX_POINTS_PER_STROKE

  var strokeColor: Int = Color.BLACK
    set(value) {
      field = value
      paint.color = value
    }

  var strokeWidthPx: Float = DEFAULT_STROKE_WIDTH_PX
    set(value) {
      field = value
      paint.strokeWidth = value
    }

  private val paint =
    Paint().apply {
      isAntiAlias = true
      style = Paint.Style.STROKE
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
      color = strokeColor
      strokeWidth = strokeWidthPx
    }

  private var onStrokeStartListener: ((strokeIndex: Int) -> Unit)? = null
  private var onStrokeEndListener: ((strokeIndex: Int, pointCount: Int) -> Unit)? = null
  private var onCanvasChangeListener: ((strokeCount: Int) -> Unit)? = null

  fun setListeners(
    onStrokeStart: (strokeIndex: Int) -> Unit,
    onStrokeEnd: (strokeIndex: Int, pointCount: Int) -> Unit,
    onCanvasChange: (strokeCount: Int) -> Unit
  ) {
    onStrokeStartListener = onStrokeStart
    onStrokeEndListener = onStrokeEnd
    onCanvasChangeListener = onCanvasChange
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        val stroke = mutableListOf(CapturedPoint(event.x, event.y, SystemClock.elapsedRealtime()))
        currentStroke = stroke
        onStrokeStartListener?.invoke(strokes.size)
      }
      MotionEvent.ACTION_MOVE -> {
        val stroke = currentStroke ?: return true
        // historySize gives us intermediate samples batched since the last
        // delivered event — capturing these keeps fast strokes smooth and
        // avoids losing fidelity ML Kit needs to recognize well.
        for (i in 0 until event.historySize) {
          if (stroke.size >= maxPointsPerStroke) break
          stroke.add(CapturedPoint(event.getHistoricalX(i), event.getHistoricalY(i), event.getHistoricalEventTime(i)))
        }
        if (stroke.size < maxPointsPerStroke) {
          stroke.add(CapturedPoint(event.x, event.y, SystemClock.elapsedRealtime()))
        }
        invalidate()
      }
      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
        finishCurrentStroke()
      }
      else -> return false
    }
    return true
  }

  private fun finishCurrentStroke() {
    val stroke = currentStroke
    currentStroke = null
    if (stroke != null && stroke.size > 1) {
      strokes.add(stroke)
      onStrokeEndListener?.invoke(strokes.size - 1, stroke.size)
      onCanvasChangeListener?.invoke(strokes.size)
    }
    invalidate()
  }

  fun clear() {
    strokes.clear()
    currentStroke = null
    invalidate()
    onCanvasChangeListener?.invoke(0)
  }

  fun undoLastStroke() {
    if (strokes.isNotEmpty()) {
      strokes.removeAt(strokes.size - 1)
      invalidate()
      onCanvasChangeListener?.invoke(strokes.size)
    }
  }

  /** Snapshots every completed stroke plus the in-progress one, if any. */
  fun snapshot(): List<CapturedStroke> {
    val snapshotted = strokes.map { CapturedStroke(it.toList()) }
    val inProgress = currentStroke?.let { listOf(CapturedStroke(it.toList())) } ?: emptyList()
    return snapshotted + inProgress
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    for (stroke in strokes) {
      drawStroke(canvas, stroke)
    }
    currentStroke?.let { drawStroke(canvas, it) }
  }

  private fun drawStroke(canvas: Canvas, points: List<CapturedPoint>) {
    if (points.isEmpty()) return
    if (points.size == 1) {
      canvas.drawPoint(points[0].x, points[0].y, paint)
      return
    }
    val path = Path()
    path.moveTo(points[0].x, points[0].y)
    for (i in 1 until points.size) {
      path.lineTo(points[i].x, points[i].y)
    }
    canvas.drawPath(path, paint)
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    // Explicit teardown: no stroke/point buffers survive past unmount, and
    // no listener keeps a reference that could fire after detach.
    strokes.clear()
    currentStroke = null
    onStrokeStartListener = null
    onStrokeEndListener = null
    onCanvasChangeListener = null
  }

  companion object {
    const val DEFAULT_MAX_POINTS_PER_STROKE = 4096
    const val DEFAULT_STROKE_WIDTH_PX = 6f

    /** Fabric-safe lookup by React tag — returns null (never throws) if the
     * view is unmounted or not (yet/any-more) resolvable on this surface. */
    fun findByReactTag(reactContext: ReactContext, viewTag: Int): DigitalInkCanvasView? {
      return try {
        val uiManager = UIManagerHelper.getUIManagerForReactTag(reactContext, viewTag)
        uiManager?.resolveView(viewTag) as? DigitalInkCanvasView
      } catch (e: Exception) {
        null
      }
    }
  }
}
