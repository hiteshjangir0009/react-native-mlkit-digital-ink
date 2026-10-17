/**
 * Native error codes. Both the Android and iOS implementations must reject
 * promises using exactly these strings as the error `code` so the JS facade
 * can map them back to a typed error class.
 */
export type DigitalInkErrorCode =
  | 'E_MODEL_NOT_DOWNLOADED'
  | 'E_UNSUPPORTED_LANGUAGE'
  | 'E_CUSTOM_MODEL_NOT_REGISTERED'
  | 'E_MODEL_FILE_NOT_FOUND'
  | 'E_INVALID_INK'
  | 'E_INVALID_CONFIG'
  | 'E_VIEW_NOT_FOUND'
  | 'E_DOWNLOAD_FAILED'
  | 'E_NATIVE_EXCEPTION';

export class DigitalInkError extends Error {
  readonly code: DigitalInkErrorCode;

  constructor(code: DigitalInkErrorCode, message: string) {
    super(message);
    this.name = 'DigitalInkError';
    this.code = code;
    // Restore the prototype chain to whichever class was actually
    // constructed (not just DigitalInkError) — required for `instanceof
    // InvalidInkError` etc. to work on every subclass when this file is
    // transpiled to a target where `class ... extends Error` doesn't
    // preserve the chain on its own.
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class ModelNotDownloadedError extends DigitalInkError {
  constructor(languageTag: string) {
    super(
      'E_MODEL_NOT_DOWNLOADED',
      `Digital ink model for language "${languageTag}" is not downloaded yet. Call downloadModel() first.`
    );
    this.name = 'ModelNotDownloadedError';
  }
}

export class UnsupportedLanguageError extends DigitalInkError {
  constructor(languageTag: string) {
    super(
      'E_UNSUPPORTED_LANGUAGE',
      `"${languageTag}" is not a supported ML Kit digital ink language tag.`
    );
    this.name = 'UnsupportedLanguageError';
  }
}

export class CustomModelNotRegisteredError extends DigitalInkError {
  constructor(modelId: string) {
    super(
      'E_CUSTOM_MODEL_NOT_REGISTERED',
      `No custom model registered under id "${modelId}". Call registerCustomModel() first.`
    );
    this.name = 'CustomModelNotRegisteredError';
  }
}

export class ModelFileNotFoundError extends DigitalInkError {
  constructor(modelPath: string) {
    super(
      'E_MODEL_FILE_NOT_FOUND',
      `Model file not found at path: ${modelPath}`
    );
    this.name = 'ModelFileNotFoundError';
  }
}

export class InvalidInkError extends DigitalInkError {
  constructor(
    message = 'Ink is empty, malformed, or exceeds the maximum allowed point count.'
  ) {
    super('E_INVALID_INK', message);
    this.name = 'InvalidInkError';
  }
}

export class InvalidConfigError extends DigitalInkError {
  constructor(message = 'Invalid recognizer configuration.') {
    super('E_INVALID_CONFIG', message);
    this.name = 'InvalidConfigError';
  }
}

export class CanvasUnmountedError extends DigitalInkError {
  constructor() {
    super('E_VIEW_NOT_FOUND', 'The DigitalInkCanvasView is no longer mounted.');
    this.name = 'CanvasUnmountedError';
  }
}

export class ModelDownloadFailedError extends DigitalInkError {
  constructor(languageTag: string, reason?: string) {
    super(
      'E_DOWNLOAD_FAILED',
      `Failed to download model for "${languageTag}"${reason ? `: ${reason}` : '.'}`
    );
    this.name = 'ModelDownloadFailedError';
  }
}

const ERROR_FACTORIES: Record<
  DigitalInkErrorCode,
  (message: string) => DigitalInkError
> = {
  E_MODEL_NOT_DOWNLOADED: (m) =>
    new DigitalInkError('E_MODEL_NOT_DOWNLOADED', m),
  E_UNSUPPORTED_LANGUAGE: (m) =>
    new DigitalInkError('E_UNSUPPORTED_LANGUAGE', m),
  E_CUSTOM_MODEL_NOT_REGISTERED: (m) =>
    new DigitalInkError('E_CUSTOM_MODEL_NOT_REGISTERED', m),
  E_MODEL_FILE_NOT_FOUND: (m) =>
    new DigitalInkError('E_MODEL_FILE_NOT_FOUND', m),
  E_INVALID_INK: (m) => new InvalidInkError(m),
  E_INVALID_CONFIG: (m) => new InvalidConfigError(m),
  E_VIEW_NOT_FOUND: (m) => new DigitalInkError('E_VIEW_NOT_FOUND', m),
  E_DOWNLOAD_FAILED: (m) => new DigitalInkError('E_DOWNLOAD_FAILED', m),
  E_NATIVE_EXCEPTION: (m) => new DigitalInkError('E_NATIVE_EXCEPTION', m),
};

/**
 * Converts whatever rejects out of a TurboModule promise call into a typed
 * `DigitalInkError`. Native rejections always carry `error.code` (set via
 * `promise.reject(code, message)` on Android and `reject(code, message, nsError)`
 * on iOS) — but we defensively fall back to a generic error for anything that
 * doesn't match the known contract (a raw JS error, a timeout, etc.) rather
 * than throwing while handling an error.
 */
export function toDigitalInkError(error: unknown): DigitalInkError {
  if (error instanceof DigitalInkError) {
    return error;
  }

  const code = (error as { code?: unknown } | null | undefined)?.code;
  const message =
    (error as { message?: unknown } | null | undefined)?.message ??
    'Unknown digital ink recognition error.';

  if (typeof code === 'string' && code in ERROR_FACTORIES) {
    return ERROR_FACTORIES[code as DigitalInkErrorCode](String(message));
  }

  return new DigitalInkError('E_NATIVE_EXCEPTION', String(message));
}
