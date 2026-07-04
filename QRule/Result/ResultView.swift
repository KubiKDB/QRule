import SwiftUI

struct ResultView: View {
    let result: ScanResult
    let onOpen: (URL) -> Void
    let onPrepareShare: () -> Void
    let onClose: () -> Void

    @State private var copied = false
    @State private var shareAnchor: NSView?

    var body: some View {
        VStack(spacing: 12) {
            Text(result.payload)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: 280)

            HStack(spacing: 4) {
                Button {
                    if let url = result.openableURL { onOpen(url) }
                } label: {
                    ActionLabel(title: "Open", systemImage: "safari")
                }
                .disabled(result.openableURL == nil)
                .keyboardShortcut(.defaultAction)

                Button {
                    copy()
                } label: {
                    ActionLabel(
                        title: copied ? "Copied" : "Copy",
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                }
                .keyboardShortcut("c", modifiers: .command)

                Button {
                    share()
                } label: {
                    ActionLabel(title: "Share", systemImage: "square.and.arrow.up")
                }
                .background(ViewAnchor(view: $shareAnchor))

                Button {
                    onClose()
                } label: {
                    ActionLabel(title: "Close", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
            }
            .buttonStyle(ResultActionButtonStyle())
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func share() {
        guard let anchor = shareAnchor else { return }
        // Drop the full-screen overlay and lower the panel below menu level,
        // otherwise the share menu is drawn behind them and never seen.
        onPrepareShare()
        NSApp.activate(ignoringOtherApps: true)
        let item: Any = result.openableURL ?? result.payload
        SharePresenter.shared.present(item: item, anchor: anchor) {
            onClose()
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.payload, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            onClose()
        }
    }
}

/// Exposes the underlying NSView of a SwiftUI element so AppKit pickers can anchor to it.
private struct ViewAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { view = nsView }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct ActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .frame(height: 20)
            Text(title)
                .font(.caption)
        }
        .frame(width: 58, height: 46)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct ResultActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .primary : Color.secondary.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : .clear)
            )
    }
}
