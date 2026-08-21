import AppKit
import Combine

/// The one workspace folder Paragraph is currently showing.
///
/// Paragraph looks inside exactly two things: files the writer opened, and the
/// folder they chose. It never enumerates iCloud Drive, a home folder, or
/// anywhere else it was not pointed at.
final class WorkspaceController: ObservableObject {
    static let shared = WorkspaceController()

    @Published private(set) var workspace: Workspace?

    private var pendingCloser: DocumentCloser?

    private init() {}

    /// The native folder chooser is the only way a workspace is ever selected.
    /// That is what grants a sandboxed Paragraph access to the folder at all.
    func chooseWorkspace(from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.openWorkspacePrompt
        panel.message = L10n.openWorkspaceMessage

        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.setWorkspace(url: url)
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    /// Switching folders closes the documents belonging to the old one, so the
    /// browser and the editor always agree about which workspace you are in.
    ///
    /// Unsaved work is not closed silently: each document is asked in the
    /// standard way, and cancelling any of them abandons the switch entirely
    /// rather than leaving half a workspace open.
    func setWorkspace(url: URL) {
        guard let previous = workspace else {
            adopt(url, inheritingFrame: frontmostDocumentWindowFrame())
            return
        }
        let belonging = NSDocumentController.shared.documents.filter { document in
            document.fileURL.map { previous.contains($0) } ?? false
        }
        guard !belonging.isEmpty else {
            adopt(url, inheritingFrame: frontmostDocumentWindowFrame())
            return
        }

        // Where the writer had put the window. If closing the old workspace's
        // files empties the screen, the replacement should appear here rather
        // than back at a default size on the main display.
        let frame = frontmostDocumentWindowFrame()

        let closer = DocumentCloser(documents: belonging) { [weak self] closed in
            self?.pendingCloser = nil
            guard closed else { return }
            self?.adopt(url, inheritingFrame: frame)
        }
        pendingCloser = closer
        closer.start()
    }

    private func frontmostDocumentWindowFrame() -> NSRect? {
        let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
            $0.windowController is DocumentWindowController && $0.isVisible
        }
        guard let window, window.windowController is DocumentWindowController else { return nil }
        return window.frame
    }

    private func adopt(_ url: URL, inheritingFrame frame: NSRect?) {
        // The bookmark is what allows this folder — including one inside iCloud
        // Drive — to be reopened on a later launch without asking again.
        if let bookmark = Workspace.makeBookmark(for: url) {
            Preferences.shared.workspaceBookmark = bookmark
        }
        Preferences.shared.expandedFolders = []
        workspace = Workspace(url: url)

        // Closing the old workspace's files may have closed every window with
        // it, leaving nowhere to see the new folder. The check waits a turn of
        // the run loop: a window that is closing is still in `NSApp.windows`
        // when the document that owned it reports itself closed.
        DispatchQueue.main.async {
            let hasWindow = NSApp.windows.contains {
                $0.windowController is DocumentWindowController && $0.isVisible
            }
            guard !hasWindow else { return }
            NSDocumentController.shared.newDocument(nil)

            // Put it back where the writer had the last one, on the display they
            // were using. Without this the replacement lands at its default size
            // on the main screen, and a window that was filling a second monitor
            // appears to have jumped back.
            guard let frame else { return }
            let replacement = NSApp.windows.first {
                $0.windowController is DocumentWindowController && $0.isVisible
            }
            replacement?.setFrame(frame, display: true)
        }
    }

    /// Reopens the folder from the stored bookmark at launch.
    @discardableResult
    func restoreSavedWorkspace() -> Bool {
        guard let bookmark = Preferences.shared.workspaceBookmark,
              let url = Workspace.resolveBookmark(bookmark),
              let restored = Workspace(url: url)
        else { return false }
        workspace = restored
        return true
    }

    func closeWorkspace() {
        workspace = nil
        Preferences.shared.workspaceBookmark = nil
        Preferences.shared.expandedFolders = []
    }
}
