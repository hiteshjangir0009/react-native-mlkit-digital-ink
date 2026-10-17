import UIKit

/// Captures handwriting strokes via raw `UITouch` events and renders them.
/// Owned by `DigitalInkCanvasViewComponentView` (the Fabric wrapper), which
/// forwards prop updates and reads the `onStrokeStart`/`onStrokeEnd`/
/// `onCanvasChange` callbacks to dispatch Fabric events.
///
/// Thread-safety: `strokeLock` guards every read/mutation of `strokes` and
/// `currentStroke` because `snapshot()`/`clear()`/`undoLastStroke()` are
/// called from the TurboModule's background queue (see
/// `DigitalInkRecognizerModuleImpl.withView`) while `touchesMoved` etc. fire
/// on the main thread — without this lock, a concurrent read/write would be
/// undefined behavior (a real crash risk), not just a data race in theory.
@objc(DigitalInkCanvasView)
public final class DigitalInkCanvasView: UIView {
  @objc public static let defaultMaxPointsPerStroke = 4096
  @objc public static let defaultStrokeWidth: CGFloat = 3.0

  private var strokes: [DigitalInkStroke] = []
  private var currentStroke: [DigitalInkPoint]?
  private let strokeLock = NSLock()

  @objc public var maxPointsPerStroke: Int = DigitalInkCanvasView.defaultMaxPointsPerStroke

  @objc public var strokeColor: UIColor = .black {
    didSet { setNeedsDisplay() }
  }

  @objc public var strokeWidth: CGFloat = DigitalInkCanvasView.defaultStrokeWidth {
    didSet { setNeedsDisplay() }
  }

  @objc public var onStrokeStart: ((Int) -> Void)?
  @objc public var onStrokeEnd: ((Int, Int) -> Void)?
  @objc public var onCanvasChange: ((Int) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isMultipleTouchEnabled = false
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    strokeLock.lock()
    let strokeIndex = strokes.count
    currentStroke = [point(from: touch)]
    strokeLock.unlock()
    onStrokeStart?(strokeIndex)
  }

  public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    strokeLock.lock()
    if currentStroke != nil {
      // Coalesced touches give full-resolution sampling (stylus-friendly),
      // matching Android's use of MotionEvent historical points.
      let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
      for coalescedTouch in coalesced {
        if currentStroke!.count >= maxPointsPerStroke { break }
        currentStroke!.append(point(from: coalescedTouch))
      }
    }
    strokeLock.unlock()
    setNeedsDisplay()
  }

  public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    finishCurrentStroke()
  }

  public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    finishCurrentStroke()
  }

  private func point(from touch: UITouch) -> DigitalInkPoint {
    let location = touch.location(in: self)
    let timestampMs = touch.timestamp * 1000
    return DigitalInkPoint(x: location.x, y: location.y, t: timestampMs)
  }

  private func finishCurrentStroke() {
    strokeLock.lock()
    let finished = currentStroke
    currentStroke = nil
    var strokeIndex = -1
    var pointCount = 0
    if let finished, finished.count > 1 {
      strokes.append(DigitalInkStroke(points: finished))
      strokeIndex = strokes.count - 1
      pointCount = finished.count
    }
    let strokeCount = strokes.count
    strokeLock.unlock()

    setNeedsDisplay()
    if strokeIndex >= 0 {
      onStrokeEnd?(strokeIndex, pointCount)
      onCanvasChange?(strokeCount)
    }
  }

  func clear() {
    strokeLock.lock()
    strokes.removeAll()
    currentStroke = nil
    strokeLock.unlock()
    setNeedsDisplay()
    onCanvasChange?(0)
  }

  func undoLastStroke() {
    strokeLock.lock()
    let hadStroke = !strokes.isEmpty
    if hadStroke { strokes.removeLast() }
    let strokeCount = strokes.count
    strokeLock.unlock()
    if hadStroke {
      setNeedsDisplay()
      onCanvasChange?(strokeCount)
    }
  }

  /// Snapshots every completed stroke plus the in-progress one, if any.
  func snapshot() -> DigitalInkInk {
    strokeLock.lock()
    defer { strokeLock.unlock() }
    var all = strokes
    if let currentStroke, !currentStroke.isEmpty {
      all.append(DigitalInkStroke(points: currentStroke))
    }
    return DigitalInkInk(strokes: all)
  }

  public override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    context.setStrokeColor(strokeColor.cgColor)
    context.setLineWidth(strokeWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    strokeLock.lock()
    let allStrokes = currentStroke.map { strokes + [DigitalInkStroke(points: $0)] } ?? strokes
    strokeLock.unlock()

    for stroke in allStrokes {
      guard let first = stroke.points.first else { continue }
      context.beginPath()
      context.move(to: CGPoint(x: first.x, y: first.y))
      for p in stroke.points.dropFirst() {
        context.addLine(to: CGPoint(x: p.x, y: p.y))
      }
      context.strokePath()
    }
  }

  /// Explicit teardown — no stroke/point buffers or callback closures
  /// survive past unmount, matching Android's `onDetachedFromWindow`.
  @objc public func teardown() {
    strokeLock.lock()
    strokes.removeAll()
    currentStroke = nil
    strokeLock.unlock()
    onStrokeStart = nil
    onStrokeEnd = nil
    onCanvasChange = nil
  }
}
