import SwiftUI
import KeyboardShortcuts
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let scanQR = Self("scanQR", default: .init(.seven, modifiers: [.command, .shift]))
}

@main
struct QRuleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("QRule", systemImage: "qrcode.viewfinder") {
            MenuContent()
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .scanQR) {
            ScanCoordinator.shared.startScan()
        }
    }
}

private struct MenuContent: View {
    var body: some View {
        Button("Scan QR Code") {
            ScanCoordinator.shared.startScan()
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        LaunchAtLoginToggle()

        Divider()

        Button("About QRule") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        }

        Button("Quit QRule") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at Login", isOn: Binding(
            get: { isEnabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    isEnabled = newValue
                } catch {
                    isEnabled = SMAppService.mainApp.status == .enabled
                }
            }
        ))
    }
}

private struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder(String(localized: "Scan shortcut:"), name: .scanQR)
            Text("Press the shortcut, then drag a box around any QR code on your screen.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360)
    }
}
