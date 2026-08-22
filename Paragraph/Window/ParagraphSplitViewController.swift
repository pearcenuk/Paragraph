import AppKit

/// The window's split view controller.
///
/// Exists only to route AppKit's own `toggleSidebar:` — sent by the standard
/// toolbar button and by the system's sidebar shortcut — through Paragraph's
/// toggle, which keeps the browser in step across the tabs of a group. Without
/// this the standard button would collapse one tab's browser and leave its
/// siblings showing theirs.
final class ParagraphSplitViewController: NSSplitViewController {

    override func toggleSidebar(_ sender: Any?) {
        guard let controller = view.window?.windowController as? DocumentWindowController else {
            super.toggleSidebar(sender)
            return
        }
        controller.toggleWorkspaceBrowser(sender)
    }
}
