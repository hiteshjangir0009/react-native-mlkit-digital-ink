import Foundation

/// Converts between the plain `NSDictionary`/`NSArray` payloads the ObjC++
/// TurboModule trampoline hands us (already flattened from codegen's C++
/// `JS::...::NativeXxx` structs — see `ReactNativeMlkitDigitalInk.mm`) and
/// our own `DigitalInkInk`/`CustomModelRegistrationData` model types.
///
/// Every parse function throws `DigitalInkError` on malformed input rather
/// than force-unwrapping/crashing — callers (the module impl) catch this
/// uniformly and reject the promise with `E_INVALID_INK` / `E_INVALID_CONFIG`.
enum InkMapper {
  /// Defensive ceiling mirrored from the JS side (`convert.ts`) and Android.
  private static let maxTotalPoints = 50_000

  static func ink(from dict: NSDictionary) throws -> DigitalInkInk {
    guard let strokesArray = dict["strokes"] as? [NSDictionary], !strokesArray.isEmpty else {
      throw DigitalInkError.invalidInk("Ink must contain at least one stroke.")
    }

    var totalPoints = 0
    var strokes: [DigitalInkStroke] = []
    strokes.reserveCapacity(strokesArray.count)

    for strokeDict in strokesArray {
      guard let pointsArray = strokeDict["points"] as? [NSDictionary] else {
        throw DigitalInkError.invalidInk("Every stroke must have a points array.")
      }
      var points: [DigitalInkPoint] = []
      points.reserveCapacity(pointsArray.count)
      for pointDict in pointsArray {
        guard let x = (pointDict["x"] as? NSNumber)?.doubleValue,
          let y = (pointDict["y"] as? NSNumber)?.doubleValue,
          let t = (pointDict["t"] as? NSNumber)?.doubleValue
        else {
          throw DigitalInkError.invalidInk("A point is missing x/y/t.")
        }
        points.append(DigitalInkPoint(x: x, y: y, t: t))
        totalPoints += 1
        if totalPoints > maxTotalPoints {
          throw DigitalInkError.invalidInk("Ink exceeds the maximum of \(maxTotalPoints) total points.")
        }
      }
      strokes.append(DigitalInkStroke(points: points))
    }

    guard totalPoints > 0 else {
      throw DigitalInkError.invalidInk("Ink has no points.")
    }

    return DigitalInkInk(strokes: strokes)
  }

  /// Converts the Fabric view's own captured-stroke snapshot directly into
  /// the JS-bridge `NativeInk` dictionary shape.
  static func dictionary(from ink: DigitalInkInk) -> NSDictionary {
    let strokes: [NSDictionary] = ink.strokes.map { stroke in
      let points: [NSDictionary] = stroke.points.map { point in
        ["x": point.x, "y": point.y, "t": point.t]
      }
      return ["points": points]
    }
    return ["strokes": strokes]
  }

  static func dictionary(from result: RecognitionResultData) -> NSDictionary {
    let candidates: [NSDictionary] = result.candidates.map { candidate in
      ["text": candidate.text, "score": candidate.score.isFinite ? candidate.score : 0]
    }
    return ["candidates": candidates]
  }

  static func dictionary(from models: [(languageTag: String, isDownloaded: Bool)]) -> [NSDictionary] {
    models.map { ["languageTag": $0.languageTag, "isDownloaded": $0.isDownloaded] }
  }

  static func customModelRegistration(from dict: NSDictionary) throws -> CustomModelRegistrationData {
    guard let modelId = dict["modelId"] as? String else {
      throw DigitalInkError.invalidConfig("registration.modelId is missing.")
    }
    guard let modelPath = dict["modelPath"] as? String else {
      throw DigitalInkError.invalidConfig("registration.modelPath is missing.")
    }
    guard let tensorSpecDict = dict["tensorSpec"] as? NSDictionary else {
      throw DigitalInkError.invalidConfig("registration.tensorSpec is missing.")
    }

    guard let inputShapeRaw = tensorSpecDict["inputShape"] as? [NSNumber] else {
      throw DigitalInkError.invalidConfig("tensorSpec.inputShape is missing.")
    }
    guard let outputShapeRaw = tensorSpecDict["outputShape"] as? [NSNumber] else {
      throw DigitalInkError.invalidConfig("tensorSpec.outputShape is missing.")
    }
    guard let preprocessing = tensorSpecDict["preprocessing"] as? String else {
      throw DigitalInkError.invalidConfig("tensorSpec.preprocessing is missing.")
    }

    let labels = (tensorSpecDict["labels"] as? [String])
    let normalizePoints = (tensorSpecDict["normalizePoints"] as? Bool) ?? false

    return CustomModelRegistrationData(
      modelId: modelId,
      modelPath: modelPath,
      tensorSpec: CustomModelTensorSpec(
        inputShape: inputShapeRaw.map(\.intValue),
        outputShape: outputShapeRaw.map(\.intValue),
        preprocessing: preprocessing,
        labels: labels,
        normalizePoints: normalizePoints
      )
    )
  }

  static func recognizerKind(from dict: NSDictionary) throws -> String {
    guard let kind = dict["kind"] as? String else {
      throw DigitalInkError.invalidConfig("config.kind is missing.")
    }
    return kind
  }
}
