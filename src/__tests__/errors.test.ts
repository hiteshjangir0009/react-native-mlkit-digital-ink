import { describe, expect, it } from '@jest/globals';
import {
  DigitalInkError,
  ModelNotDownloadedError,
  toDigitalInkError,
} from '../errors';

describe('toDigitalInkError', () => {
  it('passes through an existing DigitalInkError unchanged', () => {
    const original = new ModelNotDownloadedError('en');
    expect(toDigitalInkError(original)).toBe(original);
  });

  it('maps a known native error code to its typed class', () => {
    const native = {
      code: 'E_MODEL_NOT_DOWNLOADED',
      message: 'not downloaded',
    };
    const mapped = toDigitalInkError(native);
    expect(mapped).toBeInstanceOf(DigitalInkError);
    expect(mapped.code).toBe('E_MODEL_NOT_DOWNLOADED');
    expect(mapped.message).toBe('not downloaded');
  });

  it('falls back to E_NATIVE_EXCEPTION for an unknown code', () => {
    const native = { code: 'E_SOMETHING_UNEXPECTED', message: 'boom' };
    const mapped = toDigitalInkError(native);
    expect(mapped.code).toBe('E_NATIVE_EXCEPTION');
  });

  it('falls back to E_NATIVE_EXCEPTION for a plain Error with no code', () => {
    const mapped = toDigitalInkError(new Error('plain failure'));
    expect(mapped.code).toBe('E_NATIVE_EXCEPTION');
    expect(mapped.message).toBe('plain failure');
  });

  it('never throws, even for undefined input', () => {
    expect(() => toDigitalInkError(undefined)).not.toThrow();
    expect(toDigitalInkError(undefined).code).toBe('E_NATIVE_EXCEPTION');
  });
});
