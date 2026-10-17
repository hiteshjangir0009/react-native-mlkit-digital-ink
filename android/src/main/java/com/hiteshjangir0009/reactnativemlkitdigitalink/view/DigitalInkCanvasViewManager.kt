package com.hiteshjangir0009.reactnativemlkitdigitalink.view

import android.graphics.Color
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.DigitalInkCanvasViewManagerDelegate
import com.facebook.react.viewmanagers.DigitalInkCanvasViewManagerInterface

class DigitalInkCanvasViewManager :
  SimpleViewManager<DigitalInkCanvasView>(), DigitalInkCanvasViewManagerInterface<DigitalInkCanvasView> {

  private val delegate: ViewManagerDelegate<DigitalInkCanvasView> = DigitalInkCanvasViewManagerDelegate(this)

  override fun getName(): String = REACT_CLASS

  override fun getDelegate(): ViewManagerDelegate<DigitalInkCanvasView> = delegate

  override fun createViewInstance(context: ThemedReactContext): DigitalInkCanvasView =
    DigitalInkCanvasView(context)

  @ReactProp(name = "strokeColor")
  override fun setStrokeColor(view: DigitalInkCanvasView, value: Int?) {
    view.strokeColor = value ?: Color.BLACK
  }

  @ReactProp(name = "strokeWidth")
  override fun setStrokeWidth(view: DigitalInkCanvasView, value: Double) {
    // The generated Fabric delegate passes 0.0 when the JS prop is unset
    // (it does not consult @ReactProp default* attributes — those only
    // apply to the legacy/paper property pipeline) — substitute our own
    // real default in that case rather than rendering a zero-width stroke.
    view.strokeWidthPx =
      if (value > 0.0) PixelUtil.toPixelFromDIP(value) else DigitalInkCanvasView.DEFAULT_STROKE_WIDTH_PX
  }

  @ReactProp(name = "maxPointsPerStroke")
  override fun setMaxPointsPerStroke(view: DigitalInkCanvasView, value: Int) {
    view.maxPointsPerStroke =
      if (value > 0) value else DigitalInkCanvasView.DEFAULT_MAX_POINTS_PER_STROKE
  }

  override fun addEventEmitters(reactContext: ThemedReactContext, view: DigitalInkCanvasView) {
    view.setListeners(
      onStrokeStart = { strokeIndex ->
        dispatchEvent(reactContext) { surfaceId -> StrokeStartEvent(surfaceId, view.id, strokeIndex) }
      },
      onStrokeEnd = { strokeIndex, pointCount ->
        dispatchEvent(reactContext) { surfaceId ->
          StrokeEndEvent(surfaceId, view.id, strokeIndex, pointCount)
        }
      },
      onCanvasChange = { strokeCount ->
        dispatchEvent(reactContext) { surfaceId -> CanvasChangeEvent(surfaceId, view.id, strokeCount) }
      }
    )
  }

  private inline fun dispatchEvent(
    reactContext: ReactContext,
    crossinline makeEvent: (surfaceId: Int) -> com.facebook.react.uimanager.events.Event<*>
  ) {
    // Defensive: the view can fire a trailing touch-driven callback in the
    // brief window between detach and full teardown. Resolving a null
    // dispatcher/surface just drops the event instead of crashing.
    val dispatcher = UIManagerHelper.getEventDispatcher(reactContext) ?: return
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    dispatcher.dispatchEvent(makeEvent(surfaceId))
  }

  companion object {
    const val REACT_CLASS = "DigitalInkCanvasView"
  }
}
