import Foundation

/// Maps a React tag to its live `DigitalInkCanvasView` instance, so the
/// TurboModule's `clearCanvas`/`undoLastStroke`/`getInk` methods (which only
/// receive a numeric tag from JS) can resolve the right native view without
/// depending on any private Fabric view-resolution API.
///
/// The `DigitalInkCanvasViewComponentView` (ObjC++ Fabric wrapper) registers
/// its content view here when its `tag` is set and unregisters it in
/// `prepareForRecycle`/`dealloc` — see `DigitalInkCanvasViewComponentView.mm`.
/// Holding only a weak reference means a lookup for a tag whose view has
/// already been torn down simply returns `nil` (never a dangling pointer).
@objc(DigitalInkCanvasViewRegistry)
public final class DigitalInkCanvasViewRegistry: NSObject {
  @objc public static let shared = DigitalInkCanvasViewRegistry()

  private final class WeakBox {
    weak var value: DigitalInkCanvasView?
    init(_ value: DigitalInkCanvasView) { self.value = value }
  }

  private var entries: [Int: WeakBox] = [:]
  private let lock = NSLock()

  private override init() {}

  @objc public func register(_ view: DigitalInkCanvasView, forTag tag: Int) {
    lock.lock()
    entries[tag] = WeakBox(view)
    lock.unlock()
  }

  @objc public func unregister(forTag tag: Int) {
    lock.lock()
    entries.removeValue(forKey: tag)
    lock.unlock()
  }

  func view(forTag tag: Int) -> DigitalInkCanvasView? {
    lock.lock()
    defer { lock.unlock() }
    return entries[tag]?.value
  }
}
