import type { ColorValue, HostComponent, ViewProps } from 'react-native';
import type {
  Double,
  DirectEventHandler,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes';
import { codegenNativeComponent } from 'react-native';

/**
 * These bubbling/direct events are UI telemetry only (e.g. to drive a
 * "Recognize" button's enabled state or show a running stroke count). They
 * are NOT used to reconstruct the captured `Ink` point-by-point — streaming
 * every touch-move sample across the bridge/JSI during fast handwriting
 * would be unnecessary traffic and a jank risk. The authoritative ink is
 * always fetched in one shot via `getInk(viewTag)` on the TurboModule,
 * immediately before recognition.
 */
export interface StrokeStartEventPayload {
  strokeIndex: Int32;
}

export interface StrokeEndEventPayload {
  strokeIndex: Int32;
  pointCount: Int32;
}

export interface CanvasChangeEventPayload {
  strokeCount: Int32;
}

export interface NativeProps extends ViewProps {
  strokeColor?: ColorValue;
  strokeWidth?: Double;
  /**
   * Defensive cap on the number of points a single stroke/ink may hold.
   * Once exceeded, the native view stops appending further points to the
   * current stroke (it does not crash or throw) so a runaway/unbounded
   * drawing session can't produce an ink payload large enough to cause an
   * OOM when it's later serialized and recognized.
   */
  maxPointsPerStroke?: Int32;

  onStrokeStart?: DirectEventHandler<StrokeStartEventPayload>;
  onStrokeEnd?: DirectEventHandler<StrokeEndEventPayload>;
  onCanvasChange?: DirectEventHandler<CanvasChangeEventPayload>;
}

export default codegenNativeComponent<NativeProps>(
  'DigitalInkCanvasView'
) as HostComponent<NativeProps>;
