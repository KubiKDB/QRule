import AppKit

/// Full-screen view showing the frozen screenshot, dimmed, with a drag-to-select
/// rectangle punched out of the dim — mirrors the native ⇧⌘4 interaction.
final class SelectionView: NSView {
    enum Mode {
        case selecting
        case result // a result panel is showing; any click cancels
    }

    private let image: CGImage
    var mode: Mode = .selecting
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private(set) var selectionRect: CGRect?
    private var toastText: String?
    private var toastWorkItem: DispatchWorkItem?

    init(image: CGImage, frame: NSRect) {
        self.image = image
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        if mode == .result {
            onCancel?()
            return
        }
        clearToast()
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .selecting, let start = startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .selecting else { return }
        startPoint = nil
        guard let rect = selectionRect, rect.width >= 8, rect.height >= 8 else {
            selectionRect = nil
            needsDisplay = true
            return
        }
        onSelection?(rect)
    }

    // MARK: - Crop

    /// Crops the frozen screenshot to a rect given in view coordinates.
    func croppedImage(for rect: CGRect) -> CGImage? {
        let scaleX = CGFloat(image.width) / bounds.width
        let scaleY = CGFloat(image.height) / bounds.height
        let pixelRect = CGRect(
            x: rect.minX * scaleX,
            y: (bounds.height - rect.maxY) * scaleY, // flip: CGImage origin is top-left
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral
        return image.cropping(to: pixelRect)
    }

    // MARK: - Toast

    func showToast(_ text: String, duration: TimeInterval = 1.6) {
        toastText = text
        selectionRect = nil
        needsDisplay = true

        toastWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.clearToast() }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    private func clearToast() {
        toastWorkItem?.cancel()
        toastWorkItem = nil
        if toastText != nil {
            toastText = nil
            needsDisplay = true
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: bounds)

        // Dim everything except the selection (even-odd punch-out).
        let dimPath = CGMutablePath()
        dimPath.addRect(bounds)
        if let selection = selectionRect {
            dimPath.addRect(selection)
        }
        ctx.addPath(dimPath)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.35))
        ctx.fillPath(using: .evenOdd)

        if let selection = selectionRect {
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
            ctx.setLineWidth(1)
            ctx.stroke(selection.insetBy(dx: -0.5, dy: -0.5))
            drawSizeBadge(for: selection)
        }

        if let toastText {
            drawToast(toastText)
        }
    }

    private func drawSizeBadge(for selection: CGRect) {
        let text = "\(Int(selection.width)) × \(Int(selection.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 5
        var origin = NSPoint(x: selection.maxX - size.width - padding, y: selection.minY - size.height - 2 * padding - 4)
        origin.x = max(origin.x, 4)
        if origin.y < 4 { origin.y = selection.minY + padding + 4 }

        let badgeRect = NSRect(
            x: origin.x - padding, y: origin.y - padding,
            width: size.width + 2 * padding, height: size.height + 2 * padding
        )
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5)
        NSColor(white: 0, alpha: 0.65).setFill()
        badge.fill()
        text.draw(at: origin, withAttributes: attributes)
    }

    private func drawToast(_ message: String) {
        let text = message as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let paddingX: CGFloat = 18
        let paddingY: CGFloat = 10
        let rect = NSRect(
            x: bounds.midX - size.width / 2 - paddingX,
            y: bounds.midY - size.height / 2 - paddingY,
            width: size.width + 2 * paddingX,
            height: size.height + 2 * paddingY
        )
        let bubble = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor(white: 0, alpha: 0.7).setFill()
        bubble.fill()
        text.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}
