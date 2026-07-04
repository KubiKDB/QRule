import SwiftUI

struct PermissionView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tint)

            Text("QRule Needs Screen Recording Access")
                .font(.headline)

            Text("To read QR codes on your screen, QRule takes a single screenshot when you press the shortcut. Nothing is ever saved or sent anywhere — everything stays on your Mac.\n\nEnable QRule under Screen Recording in System Settings, then relaunch the app.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Not Now") { onClose() }
                    .keyboardShortcut(.cancelAction)

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 420)
    }
}
