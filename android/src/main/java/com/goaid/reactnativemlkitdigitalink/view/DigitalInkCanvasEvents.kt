package com.goaid.reactnativemlkitdigitalink.view

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

/**
 * UI-telemetry-only events (see the rationale comment in
 * `DigitalInkCanvasViewNativeComponent.ts`) — they are never the source of
 * truth for the captured ink, only used to drive things like a "Recognize"
 * button's enabled state.
 */
class StrokeStartEvent(surfaceId: Int, viewId: Int, private val strokeIndex: Int) :
  Event<StrokeStartEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply { putInt("strokeIndex", strokeIndex) }

  companion object {
    const val EVENT_NAME = "topStrokeStart"
  }
}

class StrokeEndEvent(
  surfaceId: Int,
  viewId: Int,
  private val strokeIndex: Int,
  private val pointCount: Int
) : Event<StrokeEndEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply {
      putInt("strokeIndex", strokeIndex)
      putInt("pointCount", pointCount)
    }

  companion object {
    const val EVENT_NAME = "topStrokeEnd"
  }
}

class CanvasChangeEvent(surfaceId: Int, viewId: Int, private val strokeCount: Int) :
  Event<CanvasChangeEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply { putInt("strokeCount", strokeCount) }

  companion object {
    const val EVENT_NAME = "topCanvasChange"
  }
}
