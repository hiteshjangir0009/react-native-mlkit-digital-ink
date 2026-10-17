export {
  listAvailableModels,
  isModelDownloaded,
  downloadModel,
  deleteModel,
  registerCustomModel,
  unregisterCustomModel,
  recognize,
  recognizeFused,
} from './recognizer';

export { DigitalInkCanvasView } from './DigitalInkCanvasView';
export type {
  DigitalInkCanvasHandle,
  DigitalInkCanvasViewProps,
} from './DigitalInkCanvasView';
export type {
  StrokeStartEventPayload,
  StrokeEndEventPayload,
  CanvasChangeEventPayload,
} from './DigitalInkCanvasViewNativeComponent';

export {
  DigitalInkError,
  ModelNotDownloadedError,
  UnsupportedLanguageError,
  CustomModelNotRegisteredError,
  ModelFileNotFoundError,
  InvalidInkError,
  InvalidConfigError,
  CanvasUnmountedError,
  ModelDownloadFailedError,
} from './errors';
export type { DigitalInkErrorCode } from './errors';

export type {
  Point,
  Stroke,
  Ink,
  RecognitionCandidate,
  RecognitionResult,
  ModelInfo,
  CustomModelPreprocessing,
  CustomModelTensorSpec,
  CustomModelRegistration,
  MlKitRecognizerConfig,
  CustomRecognizerConfig,
  RecognizerConfig,
} from './types';
