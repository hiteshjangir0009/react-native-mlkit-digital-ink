import Foundation

/// Turns a captured `DigitalInkInk` into the exact-size input `Data` a
/// custom TFLite model expects, and turns the model's raw float output back
/// into ranked `RecognitionCandidateResult`s — according to the app-supplied
/// `CustomModelTensorSpec` contract. Mirrors the Android `TensorConverter`.
///
/// Every shape mismatch, empty ink, or missing label list throws
/// `DigitalInkError(.invalidConfig, ...)` rather than letting a malformed
/// buffer reach `Interpreter.invoke()` — feeding TFLite a wrong-sized buffer
/// is a hard native crash, not a catchable Swift error.
enum TensorConverter {
  static func elementCount(_ shape: [Int]) throws -> Int {
    guard !shape.isEmpty else {
      throw DigitalInkError.invalidConfig("Tensor shape must not be empty.")
    }
    var count = 1
    for dim in shape {
      guard dim > 0 else {
        throw DigitalInkError.invalidConfig("Tensor shape dimensions must be positive, got \(shape).")
      }
      count *= dim
    }
    return count
  }

  static func buildInputData(ink: DigitalInkInk, spec: CustomModelTensorSpec) throws -> Data {
    let points = ink.strokes.flatMap { $0.points }
    guard !points.isEmpty else {
      throw DigitalInkError.invalidConfig("Ink has no points to feed to the custom model.")
    }

    switch spec.preprocessing {
    case "rasterize":
      return try rasterize(ink: ink, spec: spec)
    case "point-sequence":
      return try pointSequence(points: points, spec: spec)
    default:
      throw DigitalInkError.invalidConfig("Unknown preprocessing mode: \(spec.preprocessing)")
    }
  }

  private static func rasterize(ink: DigitalInkInk, spec: CustomModelTensorSpec) throws -> Data {
    guard spec.inputShape.count >= 2 else {
      throw DigitalInkError.invalidConfig(
        "rasterize preprocessing requires an inputShape with at least 2 dimensions (height, width), got \(spec.inputShape)."
      )
    }
    let height = spec.inputShape[spec.inputShape.count - 2]
    let width = spec.inputShape[spec.inputShape.count - 1]
    let totalElements = try elementCount(spec.inputShape)

    let allPoints = ink.strokes.flatMap { $0.points }
    let minX = allPoints.map(\.x).min() ?? 0
    let maxX = allPoints.map(\.x).max() ?? 0
    let minY = allPoints.map(\.y).min() ?? 0
    let maxY = allPoints.map(\.y).max() ?? 0
    let spanX = (maxX - minX) > 0 ? (maxX - minX) : 1
    let spanY = (maxY - minY) > 0 ? (maxY - minY) : 1

    var grid = [Float](repeating: 0, count: height * width)

    func plot(_ px: Int, _ py: Int) {
      guard px >= 0, px < width, py >= 0, py < height else { return }
      grid[py * width + px] = 1
    }

    func toGrid(_ x: Double, _ y: Double) -> (Int, Int) {
      let gx = Int(((x - minX) / spanX) * Double(width - 1))
      let gy = Int(((y - minY) / spanY) * Double(height - 1))
      return (gx, gy)
    }

    for stroke in ink.strokes {
      var previous: (Int, Int)?
      for point in stroke.points {
        let current = toGrid(point.x, point.y)
        if let previous {
          drawLine(from: previous, to: current, plot: plot)
        } else {
          plot(current.0, current.1)
        }
        previous = current
      }
    }

    var data = Data(capacity: totalElements * 4)
    let repeats = totalElements / (height * width)
    for _ in 0..<repeats {
      for value in grid {
        var v = value
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
      }
    }
    return data
  }

  /// Bresenham's line algorithm — avoids gaps between fast-moving touch samples.
  private static func drawLine(from: (Int, Int), to: (Int, Int), plot: (Int, Int) -> Void) {
    var x = from.0
    var y = from.1
    let dx = abs(to.0 - from.0)
    let dy = abs(to.1 - from.1)
    let sx = to.0 >= from.0 ? 1 : -1
    let sy = to.1 >= from.1 ? 1 : -1
    var err = dx - dy
    plot(x, y)
    var steps = 0
    let maxSteps = dx + dy + 2
    while (x != to.0 || y != to.1) && steps <= maxSteps {
      let e2 = err * 2
      if e2 > -dy {
        err -= dy
        x += sx
      }
      if e2 < dx {
        err += dx
        y += sy
      }
      plot(x, y)
      steps += 1
    }
  }

  private static func pointSequence(points: [DigitalInkPoint], spec: CustomModelTensorSpec) throws -> Data {
    guard spec.inputShape.count >= 2 else {
      throw DigitalInkError.invalidConfig(
        "point-sequence preprocessing requires an inputShape with at least 2 dimensions (maxPoints, channels), got \(spec.inputShape)."
      )
    }
    let maxPoints = spec.inputShape[spec.inputShape.count - 2]
    let channels = spec.inputShape[spec.inputShape.count - 1]
    let totalElements = try elementCount(spec.inputShape)

    let minX = points.map(\.x).min() ?? 0
    let maxX = points.map(\.x).max() ?? 0
    let minY = points.map(\.y).min() ?? 0
    let maxY = points.map(\.y).max() ?? 0
    let spanX = (maxX - minX) > 0 ? (maxX - minX) : 1
    let spanY = (maxY - minY) > 0 ? (maxY - minY) : 1

    var data = Data(capacity: totalElements * 4)
    func append(_ value: Float) {
      var v = value
      withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    var written = 0
    for point in points {
      if written >= maxPoints { break }
      let x = spec.normalizePoints ? (point.x - minX) / spanX : point.x
      let y = spec.normalizePoints ? (point.y - minY) / spanY : point.y
      append(Float(x))
      if channels >= 2 { append(Float(y)) }
      if channels >= 3 { append(Float(point.t)) }
      if channels > 3 {
        for _ in 3..<channels { append(0) }
      }
      written += 1
    }
    while written < maxPoints {
      for _ in 0..<channels { append(0) }
      written += 1
    }
    return data
  }

  static func decodeOutput(data: Data, spec: CustomModelTensorSpec) throws -> RecognitionResultData {
    guard let labels = spec.labels else {
      throw DigitalInkError.invalidConfig(
        "Custom model has no `labels` in its tensorSpec — cannot map output scores to text."
      )
    }
    let totalElements = try elementCount(spec.outputShape)
    guard totalElements == labels.count else {
      throw DigitalInkError.invalidConfig(
        "Custom model output has \(totalElements) elements but \(labels.count) labels were provided — they must match."
      )
    }
    guard data.count >= totalElements * 4 else {
      throw DigitalInkError.invalidConfig(
        "Custom model output buffer is smaller (\(data.count) bytes) than the \(totalElements * 4) bytes implied by outputShape."
      )
    }

    var scores = [Float](repeating: 0, count: totalElements)
    _ = scores.withUnsafeMutableBytes { dest in
      data.copyBytes(to: dest, count: totalElements * 4)
    }

    let candidates =
      zip(labels, scores)
      .map { RecognitionCandidateResult(text: $0, score: $1) }
      .sorted { $0.score > $1.score }

    return RecognitionResultData(candidates: candidates)
  }
}
