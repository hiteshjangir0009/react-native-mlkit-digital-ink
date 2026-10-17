/**
 * A single sampled point of a pen/finger stroke.
 */
export interface Point {
  x: number;
  y: number;
  /** Milliseconds since the stroke/ink capture started. */
  t: number;
}

/** A single continuous pen-down-to-pen-up stroke. */
export interface Stroke {
  points: Point[];
}

/** A full piece of digital ink: one or more strokes making up a word/phrase. */
export interface Ink {
  strokes: Stroke[];
}

export interface RecognitionCandidate {
  text: string;
  /** Normalized confidence in the [0, 1] range. */
  score: number;
}

export interface RecognitionResult {
  candidates: RecognitionCandidate[];
}

export interface ModelInfo {
  /** BCP-47 language tag, e.g. "en", "en-US", "hi". */
  languageTag: string;
  isDownloaded: boolean;
}

/** How raw ink should be turned into the custom model's input tensor. */
export type CustomModelPreprocessing = 'rasterize' | 'point-sequence';

export interface CustomModelTensorSpec {
  /** Full input tensor shape, e.g. [1, 64, 64, 1] or [1, 128, 3]. */
  inputShape: number[];
  /** Full output tensor shape, e.g. [1, 128]. */
  outputShape: number[];
  preprocessing: CustomModelPreprocessing;
  /** Optional fixed label list, when the output is a softmax over known classes. */
  labels?: string[];
  /** Whether point coordinates should be normalized to [0, 1] before inference. */
  normalizePoints?: boolean;
}

export interface CustomModelRegistration {
  /** Caller-chosen id used to select this model from `recognize()`. */
  modelId: string;
  /** Absolute on-disk path to a `.tflite` FlatBuffer file. */
  modelPath: string;
  tensorSpec: CustomModelTensorSpec;
}

export interface MlKitRecognizerConfig {
  kind: 'mlkit';
  languageTag: string;
}

export interface CustomRecognizerConfig {
  kind: 'custom';
  modelId: string;
}

export type RecognizerConfig = MlKitRecognizerConfig | CustomRecognizerConfig;

export type DownloadProgressListener = (progress: number) => void;
