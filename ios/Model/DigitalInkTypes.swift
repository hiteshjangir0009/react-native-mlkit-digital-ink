import Foundation

/// Plain, SDK-agnostic model types mirroring the JS `Point`/`Stroke`/`Ink`
/// shapes (`src/types.ts`). Named with a `DigitalInk` prefix to avoid any
/// collision with MLKit's own `MLKInk`/`MLKInkStroke`/`MLKInkPoint` types —
/// conversion between the two happens only at the ML Kit backend boundary.
struct DigitalInkPoint {
  let x: Double
  let y: Double
  let t: Double
}

struct DigitalInkStroke {
  let points: [DigitalInkPoint]
}

struct DigitalInkInk {
  let strokes: [DigitalInkStroke]
}

struct RecognitionCandidateResult {
  let text: String
  let score: Float
}

struct RecognitionResultData {
  let candidates: [RecognitionCandidateResult]
}

struct CustomModelTensorSpec {
  let inputShape: [Int]
  let outputShape: [Int]
  let preprocessing: String // "rasterize" | "point-sequence"
  let labels: [String]?
  let normalizePoints: Bool
}

struct CustomModelRegistrationData {
  let modelId: String
  let modelPath: String
  let tensorSpec: CustomModelTensorSpec
}
