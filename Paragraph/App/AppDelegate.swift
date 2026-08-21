import AppKit
import Combine
import ParagraphKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Instantiated before anything touches `NSDocumentController.shared`, which
    /// is how a subclass becomes the shared controller.
    private var documentController: ParagraphDocumentController?

    static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    private var didRestoreSession = false
    private var isRestoring = false
    private var sessionSaveWork: DispatchWorkItem?
    private var recentlyClosedFiles: [URL] = []
    private var observers: Set<AnyCancellable> = []

    // MARK: - Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        documentController = ParagraphDocumentController()
        NSWindow.allowsAutomaticWindowTabbing = true
        MenuBuilder.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Under XCTest the app is hosting a test bundle, not a writer. Restoring
        // a session there would open windows and possibly an alert about a file
        // that has since moved, which would hang the run.
        guard !Self.isRunningTests else {
            didRestoreSession = true
            return
        }

        WorkspaceController.shared.restoreSavedWorkspace()

        if Preferences.shared.restorePreviousSession, let session = SessionStore.load() {
            // Restoration opens and closes windows as it works; saving halfway
            // through would overwrite the very session being restored.
            isRestoring = true
            didRestoreSession = SessionRestorer.restore(session)
            isRestoring = false
        }

        NotificationCenter.default
            .publisher(for: NSWindow.willCloseNotification)
            .sink { [weak self] note in
                self?.rememberClosedWindow(note)
                self?.scheduleSessionSave()
            }
            .store(in: &observers)

        // The session is written as it changes rather than only at the end, so
        // it survives a crash or a force quit as well as a normal one.
        for name: Notification.Name in [
            NSWindow.didBecomeMainNotification,
            NSWindow.didResizeNotification,
            NSWindow.didMoveNotification
        ] {
            NotificationCenter.default
                .publisher(for: name)
                .sink { [weak self] _ in self?.scheduleSessionSave() }
                .store(in: &observers)
        }
    }

    /// A blank document only when there is nothing to come back to.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        !didRestoreSession
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        saveSessionNow()
    }

    /// Coalesces the bursts of notifications that a window resize or a tab
    /// opening produces.
    private func scheduleSessionSave() {
        guard !Self.isRunningTests, !isRestoring else { return }
        sessionSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveSessionNow() }
        sessionSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func saveSessionNow() {
        guard !Self.isRunningTests, !isRestoring else { return }
        guard Preferences.shared.restorePreviousSession else {
            SessionStore.clear()
            return
        }

        let session = SessionRestorer.captureCurrentSession()

        // Windows close one at a time as the application quits, and the last
        // capture would therefore describe an empty screen. Rather than take
        // over termination — which means taking over the document machinery's
        // own closing sequence — an empty capture simply never replaces a
        // populated session. The cost is that closing every window and then
        // quitting brings those windows back; losing an afternoon's arrangement
        // of tabs would be the worse trade.
        if session.windows.isEmpty, SessionStore.load()?.windows.isEmpty == false {
            return
        }
        SessionStore.save(session)
    }

    private func rememberClosedWindow(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let controller = window.windowController as? DocumentWindowController,
              let url = controller.markdownDocument.fileURL
        else { return }
        recentlyClosedFiles.removeAll { $0 == url }
        recentlyClosedFiles.append(url)
        if recentlyClosedFiles.count > 20 { recentlyClosedFiles.removeFirst() }
    }

    private var frontmostDocumentWindowController: DocumentWindowController? {
        if let controller = NSApp.keyWindow?.windowController as? DocumentWindowController {
            return controller
        }
        return NSApp.mainWindow?.windowController as? DocumentWindowController
    }

    // MARK: - File

    @IBAction func openWorkspaceFolder(_ sender: Any?) {
        WorkspaceController.shared.chooseWorkspace(from: NSApp.keyWindow)
    }

    @IBAction func revealCurrentDocumentInFinder(_ sender: Any?) {
        guard let url = frontmostDocumentWindowController?.markdownDocument.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - View

    @IBAction func toggleWordCount(_ sender: Any?) {
        Preferences.shared.wordCountVisible.toggle()
    }

    @IBAction func selectTheme(_ sender: Any?) {
        guard let command = (sender as? NSMenuItem)?.representedObject as? AppCommand,
              let identifier = command.themeIdentifier
        else { return }
        Preferences.shared.theme = identifier
    }

    // MARK: - Navigate

    @IBAction func showQuickOpen(_ sender: Any?) {
        QuickOpenPanelController.shared.show(relativeTo: NSApp.keyWindow)
    }

    @IBAction func reopenClosedTab(_ sender: Any?) {
        guard let url = recentlyClosedFiles.popLast() else { return }
        DocumentOpener.open(url: url, placement: .tab(in: NSApp.mainWindow))
    }

    // MARK: - Writing

    @IBAction func toggleTypewriterMode(_ sender: Any?) {
        Preferences.shared.typewriterMode.toggle()
    }

    @IBAction func toggleFocusMode(_ sender: Any?) {
        Preferences.shared.focusMode.toggle()
    }

    @IBAction func runWritingCheck(_ sender: Any?) {
        WritingCheckWindowController.shared.run(on: frontmostDocumentWindowController)
    }

    @IBAction func showWritingCheckResults(_ sender: Any?) {
        WritingCheckWindowController.shared.showResults()
    }

    // MARK: - Help and Settings

    @IBAction func showKeyboardShortcuts(_ sender: Any?) {
        ShortcutsWindowController.shared.showWindow(nil)
    }

    @IBAction func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.showWindow(nil)
    }

}

// MARK: - Menu state

/// The conformance matters: without it Swift never exposes `validateMenuItem(_:)`
/// to Objective-C, AppKit never calls it, and every checked menu item silently
/// loses its tick.
extension AppDelegate: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleTypewriterMode(_:)):
            menuItem.state = Preferences.shared.typewriterMode ? .on : .off
            return true

        case #selector(toggleFocusMode(_:)):
            menuItem.state = Preferences.shared.focusMode ? .on : .off
            return true

        case #selector(toggleWordCount(_:)):
            menuItem.state = Preferences.shared.wordCountVisible ? .on : .off
            return true

        case #selector(selectTheme(_:)):
            let command = menuItem.representedObject as? AppCommand
            menuItem.state = command?.themeIdentifier == Preferences.shared.theme ? .on : .off
            return true

        case #selector(reopenClosedTab(_:)):
            return !recentlyClosedFiles.isEmpty

        case #selector(showQuickOpen(_:)):
            return WorkspaceController.shared.workspace != nil

        case #selector(revealCurrentDocumentInFinder(_:)):
            return frontmostDocumentWindowController?.markdownDocument.fileURL != nil

        case #selector(runWritingCheck(_:)):
            return frontmostDocumentWindowController != nil

        default:
            return true
        }
    }
}
