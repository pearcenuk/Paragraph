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

    func setWorkspace(url: URL) {
        // The bookmark is what allows this folder — including one inside iCloud
        // Drive — to be reopened on a later launch without asking again.
        if let bookmark = Workspace.makeBookmark(for: url) {
            Preferences.shared.workspaceBookmark = bookmark
        }
        Preferences.shared.expandedFolders = []
        workspace = Workspace(url: url)
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
