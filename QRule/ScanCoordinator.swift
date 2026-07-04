import AppKit
import SwiftUI

/// Drives the scan flow: hotkey → capture → overlay selection → decode → result panel.
@MainActor
final class ScanCoordinator {
    static let shared = ScanCoordinator()
    private init() {}

    private var overlays: [OverlayWindowController] = []
    private var resultPanel: ResultPanel?
    private var permissionWindow: NSWindow?

    var isScanning: Bool { !overlays.isEmpty }

    func startScan() {
        guard !isScanning else { return }

        guard CaptureService.hasScreenRecordingPermission else {
            CaptureService.requestPermission()
            showPermissionWindow()
            return
        }

        Task { await beginCapture() }
    }

    private func beginCapture() async {
        let captures: [DisplayCapture]
        do {
            captures = try await CaptureService.captureAllDisplays()
        } catch {
            return
        }
        guard !captures.isEmpty, !isScanning else { return }

        NSApp.activate(ignoringOtherApps: true)

        let mouseLocation = NSEvent.mouseLocation
        for capture in captures {
            let controller = OverlayWindowController(capture: capture)
            controller.selectionView.onCancel = { [weak self] in self?.cancel() }
            controller.selectionView.onSelection = { [weak self, weak controller] rect in
                guard let self, let controller else { return }
                self.handleSelection(rect, on: controller)
            }
            overlays.append(controller)
        }
        for controller in overlays {
            let containsMouse = controller.screen.frame.contains(mouseLocation)
            controller.show(makeKey: containsMouse)
        }
        if !overlays.contains(where: { $0.screen.frame.contains(mouseLocation) }) {
            overlays.first?.show(makeKey: true)
        }
    }

    private func handleSelection(_ viewRect: CGRect, on controller: OverlayWindowController) {
        guard let cropped = controller.selectionView.croppedImage(for: viewRect) else {
            controller.selectionView.showToast(String(localized: "No QR code found"))
            return
        }

        Task {
            let result = await DecodeService.decodeQR(in: cropped)
            guard isScanning else { return }

            if let result {
                presentResult(result, for: viewRect, on: controller)
            } else {
                controller.selectionView.showToast(String(localized: "No QR code found"))
            }
        }
    }

    private func presentResult(_ result: ScanResult, for viewRect: CGRect, on controller: OverlayWindowController) {
        for overlay in overlays {
            overlay.selectionView.mode = .result
        }

        let windowRect = controller.selectionView.convert(viewRect, to: nil)
        let screenRect = controller.window.convertToScreen(windowRect)

        let panel = ResultPanel(
            result: result,
            near: screenRect,
            on: controller.screen,
            onOpen: { [weak self] url in
                self?.cancel()
                NSWorkspace.shared.open(url)
            },
            onPrepareShare: { [weak self] in
                self?.prepareForShare()
            },
            onClose: { [weak self] in
                self?.cancel()
            }
        )
        resultPanel = panel
        panel.makeKeyAndOrderFront(nil)

        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    /// Share menus render at pop-up-menu window level, far below the frozen
    /// overlay (.screenSaver) and the result panel above it. Tear down the
    /// overlay and drop the panel to a normal floating level so the share
    /// menu is visible and clickable.
    func prepareForShare() {
        for overlay in overlays {
            overlay.close()
        }
        overlays.removeAll()
        resultPanel?.level = .floating
    }

    func cancel() {
        resultPanel?.orderOut(nil)
        resultPanel = nil
        for overlay in overlays {
            overlay.close()
        }
        overlays.removeAll()
    }

    // MARK: - Permission onboarding

    private func showPermissionWindow() {
        if let window = permissionWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: PermissionView { [weak self] in
            self?.permissionWindow?.close()
            self?.permissionWindow = nil
        })
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "QRule"
        window.isReleasedWhenClosed = false
        window.center()
        permissionWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
