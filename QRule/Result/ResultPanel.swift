import AppKit
import SwiftUI

/// Borderless floating panel hosting the Open / Copy / Share / Close card,
/// positioned next to the selected QR code.
final class ResultPanel: NSPanel {
    init(result: ScanResult, near selectionScreenRect: CGRect, on screen: NSScreen, onOpen: @escaping (URL) -> Void, onPrepareShare: @escaping () -> Void, onClose: @escaping () -> Void) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false

        let hosting = NSHostingView(
            rootView: ResultView(result: result, onOpen: onOpen, onPrepareShare: onPrepareShare, onClose: onClose)
        )
        contentView = hosting

        let size = hosting.fittingSize
        setContentSize(size)
        setFrameOrigin(Self.origin(for: size, near: selectionScreenRect, on: screen))
    }

    override var canBecomeKey: Bool { true }

    /// Prefer centered below the selection; flip above if there is no room.
    private static func origin(for size: CGSize, near rect: CGRect, on screen: NSScreen) -> CGPoint {
        let visible = screen.visibleFrame
        let gap: CGFloat = 12

        var x = rect.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)

        var y = rect.minY - size.height - gap
        if y < visible.minY + 8 {
            y = min(rect.maxY + gap, visible.maxY - size.height - 8)
        }
        return CGPoint(x: x, y: y)
    }
}
