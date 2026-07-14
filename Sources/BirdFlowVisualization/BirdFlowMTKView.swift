import AppKit
import MetalKit

public final class BirdFlowMTKView: MTKView {
  public weak var birdFlowRenderer: MetalVisualizationRenderer?

  private var lastDrag: NSPoint?
  private var tracking: NSTrackingArea?

  public override var acceptsFirstResponder: Bool { true }

  public override func updateTrackingAreas() {
    if let tracking { removeTrackingArea(tracking) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    tracking = area
    super.updateTrackingAreas()
  }

  public override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard bounds.width > 0, bounds.height > 0 else { return }
    birdFlowRenderer?.setSliceProbe(
      normalized: SIMD2<Float>(
        Float(point.x / bounds.width),
        Float(point.y / bounds.height)
      ))
  }

  public override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    lastDrag = convert(event.locationInWindow, from: nil)
  }

  public override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if let previous = lastDrag {
      birdFlowRenderer?.orbit(
        deltaX: Float(point.x - previous.x),
        deltaY: Float(point.y - previous.y)
      )
    }
    lastDrag = point
  }

  public override func rightMouseDown(with event: NSEvent) {
    lastDrag = convert(event.locationInWindow, from: nil)
  }

  public override func rightMouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if let previous = lastDrag {
      birdFlowRenderer?.pan(
        deltaX: Float(point.x - previous.x),
        deltaY: Float(point.y - previous.y)
      )
    }
    lastDrag = point
  }

  public override func mouseUp(with event: NSEvent) { lastDrag = nil }
  public override func rightMouseUp(with event: NSEvent) { lastDrag = nil }

  public override func scrollWheel(with event: NSEvent) {
    birdFlowRenderer?.zoom(delta: Float(event.scrollingDeltaY))
  }
}
