import AppKit

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// One borderless window per display, covering it with the frozen screenshot.
final class OverlayWindowController {
    let window: NSWindow
    let selectionView: SelectionView
    let screen: NSScreen

    init(capture: DisplayCapture) {
        screen = capture.screen

        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false

        let view = SelectionView(
            image: capture.image,
            frame: NSRect(origin: .zero, size: screen.frame.size)
        )
        window.contentView = view

        self.window = window
        self.selectionView = view
    }

    func show(makeKey: Bool) {
        window.setFrame(screen.frame, display: true)
        if makeKey {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(selectionView)
        } else {
            window.orderFront(nil)
        }
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
    }
}
