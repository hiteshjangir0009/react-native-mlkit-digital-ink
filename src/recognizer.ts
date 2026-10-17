import NativeDigitalInkRecognizer from './NativeReactNativeMlkitDigitalInk';
import {
  configToNative,
  customModelRegistrationToNative,
  inkToNative,
  modelInfoFromNative,
  resultFromNative,
} from './convert';
import { toDigitalInkError } from './errors';
import type {
  CustomModelRegistration,
  Ink,
  ModelInfo,
  RecognitionResult,
  RecognizerConfig,
} from './types';

/** Lists every ML Kit digital-ink language model and whether it's downloaded on-device. */
export async function listAvailableModels(): Promise<ModelInfo[]> {
  try {
    const result = await NativeDigitalInkRecognizer.listAvailableModels();
    return result.map(modelInfoFromNative);
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

export async function isModelDownloaded(languageTag: string): Promise<boolean> {
  try {
    return await NativeDigitalInkRecognizer.isModelDownloaded(languageTag);
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

/** Downloads the on-device ML Kit model for `languageTag`. Resolves once the download completes. */
export async function downloadModel(languageTag: string): Promise<void> {
  try {
    await NativeDigitalInkRecognizer.downloadModel(languageTag);
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

export async function deleteModel(languageTag: string): Promise<void> {
  try {
    await NativeDigitalInkRecognizer.deleteModel(languageTag);
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

/**
 * Registers a custom TensorFlow Lite model (e.g. one fine-tuned on clinical
 * handwriting) under `registration.modelId`, so it can be selected later via
 * `recognize(ink, { kind: 'custom', modelId })`. Re-registering the same
 * `modelId` safely replaces the previous model.
 */
export async function registerCustomModel(
  registration: CustomModelRegistration
): Promise<void> {
  try {
    await NativeDigitalInkRecognizer.registerCustomModel(
      customModelRegistrationToNative(registration)
    );
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

export async function unregisterCustomModel(modelId: string): Promise<void> {
  try {
    await NativeDigitalInkRecognizer.unregisterCustomModel(modelId);
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

/**
 * Recognizes handwritten `ink` using either the ML Kit backend (Google's
 * pretrained per-language models) or a previously registered custom TFLite
 * model — selected via `config.kind`. Both backends return results in the
 * same `RecognitionResult` shape so callers can fuse or compare candidates
 * from either engine without caring which one produced them.
 */
export async function recognize(
  ink: Ink,
  config: RecognizerConfig
): Promise<RecognitionResult> {
  try {
    const nativeResult = await NativeDigitalInkRecognizer.recognize(
      inkToNative(ink),
      configToNative(config)
    );
    return resultFromNative(nativeResult);
  } catch (error) {
    throw toDigitalInkError(error);
  }
}

/**
 * Runs both backends and merges their candidates into one ranked list,
 * de-duplicating by recognized text and keeping the higher score when both
 * engines agree. Useful when you want ML Kit's broad-language baseline and a
 * clinical-handwriting-tuned custom model to vote together instead of
 * picking one engine up front.
 */
export async function recognizeFused(
  ink: Ink,
  mlkitLanguageTag: string,
  customModelId: string
): Promise<RecognitionResult> {
  const [mlkitResult, customResult] = await Promise.allSettled([
    recognize(ink, { kind: 'mlkit', languageTag: mlkitLanguageTag }),
    recognize(ink, { kind: 'custom', modelId: customModelId }),
  ]);

  const merged = new Map<string, number>();
  for (const settled of [mlkitResult, customResult]) {
    if (settled.status !== 'fulfilled') continue;
    for (const candidate of settled.value.candidates) {
      const existing = merged.get(candidate.text);
      if (existing === undefined || candidate.score > existing) {
        merged.set(candidate.text, candidate.score);
      }
    }
  }

  if (merged.size === 0) {
    // Both backends failed — surface whichever error is more specific
    // rather than swallowing both into a generic message.
    const firstRejection = [mlkitResult, customResult].find(
      (settled): settled is PromiseRejectedResult =>
        settled.status === 'rejected'
    );
    throw firstRejection
      ? toDigitalInkError(firstRejection.reason)
      : toDigitalInkError(undefined);
  }

  return {
    candidates: [...merged.entries()]
      .map(([text, score]) => ({ text, score }))
      .sort((a, b) => b.score - a.score),
  };
}
