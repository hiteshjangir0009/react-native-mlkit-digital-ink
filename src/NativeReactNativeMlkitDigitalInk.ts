import { TurboModuleRegistry, type TurboModule } from 'react-native';

/**
 * Codegen cannot parse discriminated unions or arbitrarily nested TS types,
 * so every type crossing the TurboModule boundary here is a flat object
 * literal using only codegen-supported primitives. The rich, ergonomic
 * types in `types.ts` are converted to/from these shapes in `recognizer.ts`
 * and `DigitalInkCanvasView.tsx` — never trust these fields blindly on the
 * native side either, since a stale/hand-rolled JS caller could still send
 * malformed data.
 */
export interface NativePoint {
  x: number;
  y: number;
  t: number;
}

export interface NativeStroke {
  points: NativePoint[];
}

export interface NativeInk {
  strokes: NativeStroke[];
}

export interface NativeRecognitionCandidate {
  text: string;
  score: number;
}

export interface NativeRecognitionResult {
  candidates: NativeRecognitionCandidate[];
}

export interface NativeModelInfo {
  languageTag: string;
  isDownloaded: boolean;
}

/**
 * Flattened recognizer selector. `kind` is `'mlkit' | 'custom'`; exactly one
 * of `languageTag` / `modelId` is populated depending on `kind`. Modeled as
 * plain optional strings (not a union) because codegen cannot express a
 * union of object shapes for a single parameter.
 */
export interface NativeRecognizerConfig {
  kind: string;
  languageTag?: string;
  modelId?: string;
}

export interface NativeCustomModelTensorSpec {
  inputShape: number[];
  outputShape: number[];
  preprocessing: string;
  labels?: string[];
  normalizePoints?: boolean;
}

export interface NativeCustomModelRegistration {
  modelId: string;
  modelPath: string;
  tensorSpec: NativeCustomModelTensorSpec;
}

export interface Spec extends TurboModule {
  // --- ML Kit model management ---
  listAvailableModels(): Promise<NativeModelInfo[]>;
  isModelDownloaded(languageTag: string): Promise<boolean>;
  downloadModel(languageTag: string): Promise<void>;
  deleteModel(languageTag: string): Promise<void>;

  // --- custom TensorFlow Lite model management ---
  registerCustomModel(
    registration: NativeCustomModelRegistration
  ): Promise<void>;
  unregisterCustomModel(modelId: string): Promise<void>;

  // --- recognition ---
  recognize(
    ink: NativeInk,
    config: NativeRecognizerConfig
  ): Promise<NativeRecognitionResult>;

  // --- imperative DigitalInkCanvasView operations, addressed by React tag.
  // These live on the module (not as Fabric view commands) because Fabric
  // commands are fire-and-forget and cannot return a Promise value. ---
  clearCanvas(viewTag: number): Promise<void>;
  undoLastStroke(viewTag: number): Promise<void>;
  getInk(viewTag: number): Promise<NativeInk>;
}

export default TurboModuleRegistry.getEnforcing<Spec>(
  'ReactNativeMlkitDigitalInk'
);
