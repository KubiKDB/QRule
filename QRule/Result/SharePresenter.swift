import AppKit

/// Presents NSSharingServicePicker and keeps it (and its delegate) alive
/// for the duration of the menu.
final class SharePresenter: NSObject, NSSharingServicePickerDelegate {
    static let shared = SharePresenter()
    private override init() {}

    private var picker: NSSharingServicePicker?
    private var onDidShare: (() -> Void)?

    func present(item: Any, anchor: NSView, onDidShare: @escaping () -> Void) {
        let picker = NSSharingServicePicker(items: [item])
        picker.delegate = self
        self.picker = picker
        self.onDidShare = onDidShare
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        sharingServicePicker.delegate = nil
        picker = nil
        // service == nil means the user dismissed the menu — keep the panel open.
        if service != nil {
            onDidShare?()
        }
        onDidShare = nil
    }
}
