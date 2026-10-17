import { InvalidConfigError, InvalidInkError } from './errors';
import type {
  NativeCustomModelRegistration,
  NativeCustomModelTensorSpec,
  NativeInk,
  NativeModelInfo,
  NativeRecognitionResult,
  NativeRecognizerConfig,
} from './NativeReactNativeMlkitDigitalInk';
import type {
  CustomModelRegistration,
  CustomModelTensorSpec,
  Ink,
  ModelInfo,
  RecognitionResult,
  RecognizerConfig,
} from './types';

/** Hard ceiling on total points in a single `Ink`, applied on the JS side as
 * a first line of defense before the payload ever reaches native code
 * (native enforces its own cap independently — see `maxPointsPerStroke`). */
const MAX_TOTAL_POINTS = 50_000;

export function inkToNative(ink: Ink): NativeInk {
  if (!ink || !Array.isArray(ink.strokes) || ink.strokes.length === 0) {
    throw new InvalidInkError('Ink must contain at least one stroke.');
  }

  let totalPoints = 0;
  for (const stroke of ink.strokes) {
    if (!stroke || !Array.isArray(stroke.points)) {
      throw new InvalidInkError('Every stroke must have a points array.');
    }
    totalPoints += stroke.points.length;
  }
  if (totalPoints === 0) {
    throw new InvalidInkError('Ink has no points.');
  }
  if (totalPoints > MAX_TOTAL_POINTS) {
    throw new InvalidInkError(
      `Ink exceeds the maximum of ${MAX_TOTAL_POINTS} total points.`
    );
  }

  return {
    strokes: ink.strokes.map((stroke) => ({
      points: stroke.points.map((point) => ({
        x: point.x,
        y: point.y,
        t: point.t,
      })),
    })),
  };
}

export function inkFromNative(native: NativeInk): Ink {
  return {
    strokes: (native?.strokes ?? []).map((stroke) => ({
      points: (stroke?.points ?? []).map((point) => ({
        x: point.x,
        y: point.y,
        t: point.t,
      })),
    })),
  };
}

export function configToNative(
  config: RecognizerConfig
): NativeRecognizerConfig {
  if (!config || typeof config.kind !== 'string') {
    throw new InvalidConfigError();
  }
  switch (config.kind) {
    case 'mlkit':
      if (!config.languageTag) {
        throw new InvalidConfigError(
          'mlkit recognizer config requires a languageTag.'
        );
      }
      return { kind: 'mlkit', languageTag: config.languageTag };
    case 'custom':
      if (!config.modelId) {
        throw new InvalidConfigError(
          'custom recognizer config requires a modelId.'
        );
      }
      return { kind: 'custom', modelId: config.modelId };
    default:
      throw new InvalidConfigError(
        `Unknown recognizer kind: ${(config as { kind: string }).kind}`
      );
  }
}

export function resultFromNative(
  native: NativeRecognitionResult
): RecognitionResult {
  return {
    candidates: (native?.candidates ?? []).map((candidate) => ({
      text: candidate.text,
      score: Number.isFinite(candidate.score) ? candidate.score : 0,
    })),
  };
}

export function modelInfoFromNative(native: NativeModelInfo): ModelInfo {
  return { languageTag: native.languageTag, isDownloaded: native.isDownloaded };
}

function tensorSpecToNative(
  spec: CustomModelTensorSpec
): NativeCustomModelTensorSpec {
  if (!Array.isArray(spec.inputShape) || spec.inputShape.length === 0) {
    throw new InvalidConfigError(
      'tensorSpec.inputShape must be a non-empty array.'
    );
  }
  if (!Array.isArray(spec.outputShape) || spec.outputShape.length === 0) {
    throw new InvalidConfigError(
      'tensorSpec.outputShape must be a non-empty array.'
    );
  }
  return {
    inputShape: spec.inputShape,
    outputShape: spec.outputShape,
    preprocessing: spec.preprocessing,
    labels: spec.labels,
    normalizePoints: spec.normalizePoints,
  };
}

export function customModelRegistrationToNative(
  registration: CustomModelRegistration
): NativeCustomModelRegistration {
  if (!registration.modelId) {
    throw new InvalidConfigError('registerCustomModel requires a modelId.');
  }
  if (!registration.modelPath) {
    throw new InvalidConfigError('registerCustomModel requires a modelPath.');
  }
  return {
    modelId: registration.modelId,
    modelPath: registration.modelPath,
    tensorSpec: tensorSpecToNative(registration.tensorSpec),
  };
}
