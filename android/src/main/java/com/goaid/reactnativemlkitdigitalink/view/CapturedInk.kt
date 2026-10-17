package com.goaid.reactnativemlkitdigitalink.view

/** A single sampled touch point, in view-local pixel coordinates. */
data class CapturedPoint(val x: Float, val y: Float, val t: Long)

/** A completed (or in-progress) pen-down-to-pen-up stroke. */
data class CapturedStroke(val points: List<CapturedPoint>)
