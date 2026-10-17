import { describe, expect, it } from '@jest/globals';
import {
  configToNative,
  customModelRegistrationToNative,
  inkFromNative,
  inkToNative,
} from '../convert';
import { InvalidConfigError, InvalidInkError } from '../errors';
import type { Ink } from '../types';

describe('inkToNative', () => {
  it('converts a well-formed ink', () => {
    const ink: Ink = {
      strokes: [
        {
          points: [
            { x: 1, y: 2, t: 0 },
            { x: 3, y: 4, t: 10 },
          ],
        },
      ],
    };
    expect(inkToNative(ink)).toEqual({
      strokes: [
        {
          points: [
            { x: 1, y: 2, t: 0 },
            { x: 3, y: 4, t: 10 },
          ],
        },
      ],
    });
  });

  it('rejects an ink with no strokes', () => {
    expect(() => inkToNative({ strokes: [] })).toThrow(InvalidInkError);
  });

  it('rejects an ink whose strokes have no points', () => {
    expect(() => inkToNative({ strokes: [{ points: [] }] })).toThrow(
      InvalidInkError
    );
  });

  it('rejects an ink exceeding the max point count', () => {
    const points = Array.from({ length: 50_001 }, (_, i) => ({
      x: i,
      y: i,
      t: i,
    }));
    expect(() => inkToNative({ strokes: [{ points }] })).toThrow(
      InvalidInkError
    );
  });
});

describe('inkFromNative', () => {
  it('round-trips an empty strokes array defensively', () => {
    // @ts-expect-error exercising a malformed native payload defensively
    expect(inkFromNative({})).toEqual({ strokes: [] });
  });
});

describe('configToNative', () => {
  it('passes through a valid mlkit config', () => {
    expect(configToNative({ kind: 'mlkit', languageTag: 'en' })).toEqual({
      kind: 'mlkit',
      languageTag: 'en',
    });
  });

  it('passes through a valid custom config', () => {
    expect(configToNative({ kind: 'custom', modelId: 'abc' })).toEqual({
      kind: 'custom',
      modelId: 'abc',
    });
  });

  it('rejects mlkit config missing languageTag', () => {
    // @ts-expect-error missing required field
    expect(() => configToNative({ kind: 'mlkit' })).toThrow(InvalidConfigError);
  });

  it('rejects custom config missing modelId', () => {
    // @ts-expect-error missing required field
    expect(() => configToNative({ kind: 'custom' })).toThrow(
      InvalidConfigError
    );
  });

  it('rejects an unknown kind', () => {
    // @ts-expect-error exercising an invalid discriminant
    expect(() => configToNative({ kind: 'bogus' })).toThrow(InvalidConfigError);
  });
});

describe('customModelRegistrationToNative', () => {
  it('passes through a valid registration', () => {
    const native = customModelRegistrationToNative({
      modelId: 'm1',
      modelPath: '/tmp/model.tflite',
      tensorSpec: {
        inputShape: [1, 64, 64, 1],
        outputShape: [1, 10],
        preprocessing: 'rasterize',
        normalizePoints: true,
      },
    });
    expect(native.modelId).toBe('m1');
    expect(native.tensorSpec.inputShape).toEqual([1, 64, 64, 1]);
  });

  it('rejects a registration with an empty inputShape', () => {
    expect(() =>
      customModelRegistrationToNative({
        modelId: 'm1',
        modelPath: '/tmp/model.tflite',
        tensorSpec: {
          inputShape: [],
          outputShape: [1],
          preprocessing: 'rasterize',
          normalizePoints: false,
        },
      })
    ).toThrow(InvalidConfigError);
  });
});
