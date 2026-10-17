# @hiteshjangir0009/react-native-mlkit-digital-ink

React Native (New Architecture only — TurboModule + Fabric) wrapper around Google ML Kit's on-device Digital Ink Recognition, plus a pluggable custom TensorFlow Lite recognizer for domain-specific handwriting (e.g. clinical/doctor handwriting) that ML Kit's own models were never trained on.

- **`<DigitalInkCanvasView>`** — a native Fabric view that captures pen/finger strokes directly (no JS round-trip per touch sample).
- **ML Kit backend** — Google's ~300 bundled per-language/script digital ink models: list, download, delete, recognize.
- **Custom backend** — register your own `.tflite` model (trained separately on your own handwriting dataset) and recognize against it through the same API shape.
- **`recognizeFused`** — runs both backends and merges candidates, so you aren't limited to ML Kit's accuracy ceiling alone.

## Requirements

- React Native **>= 0.76** (New Architecture must be enabled — RN 0.81+ has no other option).
- iOS **15.5+** (`GoogleMLKit/DigitalInkRecognition` requires it). Add to your app's `ios/Podfile`, above `use_react_native!`:
  ```ruby
  platform :ios, '15.5'
  ```
- Android **minSdk 24+**.

### A known ML Kit SDK limitation

`MLKitDigitalInkRecognition` ships without an arm64 iOS Simulator slice (`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` in its own podspec — this is Google's build, not something this package can change). On an Apple Silicon Mac, run the app on a **physical device** or an **x86_64 simulator**; a native arm64 Simulator build will fail to link.

## Installation

```sh
npm install @hiteshjangir0009/react-native-mlkit-digital-ink
cd ios && pod install
```

## Usage

```tsx
import { useRef } from 'react';
import {
  DigitalInkCanvasView,
  type DigitalInkCanvasHandle,
  downloadModel,
  isModelDownloaded,
  recognize,
} from '@hiteshjangir0009/react-native-mlkit-digital-ink';

function HandwritingInput() {
  const canvasRef = useRef<DigitalInkCanvasHandle>(null);

  const onRecognize = async () => {
    if (!(await isModelDownloaded('en'))) {
      await downloadModel('en');
    }
    const ink = await canvasRef.current!.getInk();
    const result = await recognize(ink, { kind: 'mlkit', languageTag: 'en' });
    console.log(result.candidates); // [{ text: 'hello', score: ... }, ...]
  };

  return (
    <DigitalInkCanvasView
      ref={canvasRef}
      style={{ height: 220 }}
      strokeColor="#1a1a2e"
      strokeWidth={3}
    />
  );
}
```

### Custom model (clinical handwriting, etc.)

ML Kit's Digital Ink Recognition is a closed set of Google-trained per-language models — there is no API to retrain or fine-tune it. To recognize handwriting it wasn't trained for (e.g. medical shorthand), train your own TensorFlow Lite model separately and register it:

```ts
import { registerCustomModel, recognize } from '@hiteshjangir0009/react-native-mlkit-digital-ink';

await registerCustomModel({
  modelId: 'clinical-v1',
  modelPath: '/path/to/clinical_handwriting.tflite', // bundled asset copied to disk, or downloaded
  tensorSpec: {
    inputShape: [1, 64, 64, 1], // matches your model's expected input tensor
    outputShape: [1, 128],
    preprocessing: 'rasterize', // or 'point-sequence' for a sequence model
    labels: [/* 128 label strings, aligned to the output tensor */],
    normalizePoints: true,
  },
});

const result = await recognize(ink, { kind: 'custom', modelId: 'clinical-v1' });
```

Both backends return the same `RecognitionResult` shape (`{ candidates: [{ text, score }] }`), so your app can treat them interchangeably — or call `recognizeFused(ink, 'en', 'clinical-v1')` to merge candidates from both.

## API

| Function | Description |
| --- | --- |
| `listAvailableModels()` | All ML Kit language models and their download status. |
| `isModelDownloaded(languageTag)` | Whether a given model is downloaded. |
| `downloadModel(languageTag)` | Downloads a model on-device. |
| `deleteModel(languageTag)` | Deletes a downloaded model. |
| `registerCustomModel(registration)` | Loads a `.tflite` model for the `custom` backend. |
| `unregisterCustomModel(modelId)` | Unloads a previously registered custom model. |
| `recognize(ink, config)` | Recognizes ink via `{ kind: 'mlkit', languageTag }` or `{ kind: 'custom', modelId }`. |
| `recognizeFused(ink, languageTag, modelId)` | Runs both backends and merges ranked candidates. |
| `<DigitalInkCanvasView>` | Native stroke-capture view; ref exposes `clear()`, `undo()`, `getInk()`. |

Errors are rejected as typed `DigitalInkError` subclasses (`ModelNotDownloadedError`, `UnsupportedLanguageError`, `CustomModelNotRegisteredError`, `InvalidInkError`, `CanvasUnmountedError`, etc.) — see `src/errors.ts` for the full set and their `.code` strings.

## Crash-safety design

Every native entry point (both platforms) follows the same contract:

- Every TurboModule method body is wrapped so a native exception becomes a rejected promise, never a crash — callers always get a typed `DigitalInkError`, even for inputs the JS layer didn't already validate.
- Recognition is refused with `E_MODEL_NOT_DOWNLOADED` rather than attempting it against a model that isn't there yet.
- The TensorFlow Lite `Interpreter` (not thread-safe on either platform) is always called under a lock, so concurrent `recognize()` calls against the same custom model can't corrupt it.
- `DigitalInkCanvasView.getInk()`/`clear()`/`undo()` resolve to a clean error (`E_VIEW_NOT_FOUND`) instead of crashing when the view has already unmounted.
- Ink point counts are capped (JS and native) to avoid unbounded memory growth from a runaway drawing session.

## Development

This repo contains the library (`src/`, `android/`, `ios/`) and a `example/` test-app for manual QA on both platforms. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
