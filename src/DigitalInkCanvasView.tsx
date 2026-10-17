import React, { forwardRef, useImperativeHandle, useRef } from 'react';
import {
  findNodeHandle,
  type ColorValue,
  type NativeSyntheticEvent,
} from 'react-native';
import NativeDigitalInkCanvasView, {
  type CanvasChangeEventPayload,
  type StrokeEndEventPayload,
  type StrokeStartEventPayload,
} from './DigitalInkCanvasViewNativeComponent';
import NativeDigitalInkRecognizer from './NativeReactNativeMlkitDigitalInk';
import type { Ink } from './types';
import { inkFromNative } from './convert';
import { CanvasUnmountedError } from './errors';

export interface DigitalInkCanvasViewProps {
  strokeColor?: ColorValue;
  strokeWidth?: number;
  /** Defensive cap on points per stroke. Defaults to the native default (4096) when omitted. */
  maxPointsPerStroke?: number;
  style?: React.ComponentProps<typeof NativeDigitalInkCanvasView>['style'];
  onStrokeStart?: (payload: StrokeStartEventPayload) => void;
  onStrokeEnd?: (payload: StrokeEndEventPayload) => void;
  onCanvasChange?: (payload: CanvasChangeEventPayload) => void;
}

export interface DigitalInkCanvasHandle {
  /** Clears all captured strokes. No-ops silently if the view is already unmounted. */
  clear(): Promise<void>;
  /** Removes the most recently completed stroke. No-ops silently if the view is already unmounted. */
  undo(): Promise<void>;
  /** Snapshots the currently captured ink. Rejects if the view is unmounted. */
  getInk(): Promise<Ink>;
}

type NativeViewRef = React.ElementRef<typeof NativeDigitalInkCanvasView>;

/**
 * Resolves the view's current React tag, or `null` if it's already
 * unmounted. Every imperative method below checks this *first* so an
 * in-flight call racing against unmount degrades to a silent no-op /
 * clean rejection instead of reaching into native code with a stale tag.
 */
function resolveTag(ref: React.RefObject<NativeViewRef | null>): number | null {
  if (ref.current == null) {
    return null;
  }
  return findNodeHandle(ref.current) ?? null;
}

export const DigitalInkCanvasView = forwardRef<
  DigitalInkCanvasHandle,
  DigitalInkCanvasViewProps
>(function DigitalInkCanvasViewImpl(props, ref) {
  const { onStrokeStart, onStrokeEnd, onCanvasChange, ...nativeProps } = props;
  const nativeRef = useRef<NativeViewRef>(null);

  useImperativeHandle(
    ref,
    (): DigitalInkCanvasHandle => ({
      clear: async () => {
        const tag = resolveTag(nativeRef);
        if (tag == null) return;
        await NativeDigitalInkRecognizer.clearCanvas(tag);
      },
      undo: async () => {
        const tag = resolveTag(nativeRef);
        if (tag == null) return;
        await NativeDigitalInkRecognizer.undoLastStroke(tag);
      },
      getInk: async () => {
        const tag = resolveTag(nativeRef);
        if (tag == null) {
          // Throw the same typed error whether the rejection comes from
          // JS (unmounted here) or native (view not found on the Fabric
          // surface despite a live tag) — callers get one consistent shape.
          throw new CanvasUnmountedError();
        }
        const nativeInk = await NativeDigitalInkRecognizer.getInk(tag);
        return inkFromNative(nativeInk);
      },
    }),
    []
  );

  const handleStrokeStart = onStrokeStart
    ? (event: NativeSyntheticEvent<StrokeStartEventPayload>) =>
        onStrokeStart(event.nativeEvent)
    : undefined;
  const handleStrokeEnd = onStrokeEnd
    ? (event: NativeSyntheticEvent<StrokeEndEventPayload>) =>
        onStrokeEnd(event.nativeEvent)
    : undefined;
  const handleCanvasChange = onCanvasChange
    ? (event: NativeSyntheticEvent<CanvasChangeEventPayload>) =>
        onCanvasChange(event.nativeEvent)
    : undefined;

  return (
    <NativeDigitalInkCanvasView
      ref={nativeRef}
      {...nativeProps}
      onStrokeStart={handleStrokeStart}
      onStrokeEnd={handleStrokeEnd}
      onCanvasChange={handleCanvasChange}
    />
  );
});
