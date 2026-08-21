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
            adopt(url)
            return
        }
        let belonging = NSDocumentController.shared.documents.filter { document in
            document.fileURL.map { previous.contains($0) } ?? false
        }
        guard !belonging.isEmpty else {
            adopt(url)
            return
        }

        let closer = DocumentCloser(documents: belonging) { [weak self] closed in
            self?.pendingCloser = nil
            guard closed else { return }
            self?.adopt(url)
        }
        pendingCloser = closer
        closer.start()
    }

    private func adopt(_ url: URL) {
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
            if !hasWindow {
                NSDocumentController.shared.newDocument(nil)
            }
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
