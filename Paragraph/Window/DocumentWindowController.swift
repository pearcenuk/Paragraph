import AppKit
import Combine

/// One window onto one document, which may be a tab in a group of them.
///
/// Paragraph uses macOS's own window tabbing rather than drawing its own tab
/// bar. Each tab really is a window, which is what gives dragging to reorder,
/// "Move Tab to New Window", the tab overview, and the correct accessibility
/// behaviour without a line of code. The Workspace Browser is kept in step
/// across the tabs of one group so the group behaves like the single window a
/// writer perceives it to be.
final class DocumentWindowController: NSWindowController {

    private static let tabbingIdentifier = NSWindow.TabbingIdentifier("ParagraphDocument")
    static let defaultContentSize = NSSize(width: 1000, height: 720)

    let markdownDocument: MarkdownDocument
    let browserViewController: WorkspaceBrowserViewController
    let editorViewController: EditorViewController

    private var splitViewController: NSSplitViewController!
    private var sidebarItem: NSSplitViewItem!
    private var observers: Set<AnyCancellable> = []

    init(markdownDocument: MarkdownDocument) {
        self.markdownDocument = markdownDocument
        self.browserViewController = WorkspaceBrowserViewController()
        self.editorViewController = EditorViewController(document: markdownDocument)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.tabbingMode = .automatic
        window.minSize = NSSize(width: 480, height: 320)
        // Paragraph restores its own session deliberately, so AppKit's parallel
        // restoration is switched off rather than left to compete with it.
        window.isRestorable = false

        super.init(window: window)
        shouldCascadeWindows = true
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Content

    private func buildContent() {
        browserViewController.delegate = self
        browserViewController.setWorkspace(WorkspaceController.shared.workspace)

        sidebarItem = NSSplitViewItem(sidebarWithViewController: browserViewController)
        sidebarItem.minimumThickness = 170
        sidebarItem.maximumThickness = 420
        sidebarItem.canCollapse = true

        let contentItem = NSSplitViewItem(viewController: editorViewController)
        contentItem.minimumThickness = 320

        splitViewController = ParagraphSplitViewController()
        // The stock divider is invisible when both sides are near-black, as they
        // are in Green Screen. A themed one keeps the boundary readable.
        splitViewController.splitView = ParagraphSplitView()
        splitViewController.splitView.isVertical = true
        splitViewController.splitView.dividerStyle = .thin
        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
        // Lets macOS remember how wide the writer dragged the browser.
        splitViewController.splitView.autosaveName = "ParagraphSidebar"

        window?.contentViewController = splitViewController
        // Assigning `contentViewController` resizes the window to the view
        // controller's fitting size, which for a split view is barely more than
        // its minimum thicknesses. Restore a size worth writing in.
        window?.setContentSize(Self.defaultContentSize)
        // The tab bar underneath already shows the document name, centred,
        // per tab — the same text repeated in the titlebar above it fixes the
        // sidebar button's position, since toolbar items lay out after
        // wherever that text block ends. Hiding it here removes a genuine
        // duplicate, and leaves the whole row free for the button to sit at
        // its true leading edge.
        window?.titleVisibility = .hidden
        window?.toolbar = makeToolbar()

        // The browser starts open. Deciding from the current workspace would be
        // wrong as well as fiddly: the first window is built during
        // `finishLaunching`, before the saved workspace has been resolved. When
        // there is no workspace the browser shows its "Choose Folder…" empty
        // state, which is the most useful thing a new writer can be shown.
        // Session restoration sets this per window afterwards.

        // The sidebar's material belongs to the window, not to the browser's
        // view. Setting the appearance only on descendants left a Light theme
        // drawing black text on the system's dark sidebar material.
        applyTheme(Preferences.shared.currentTheme)
        Preferences.shared.$theme
            .receive(on: RunLoop.main)
            .sink { [weak self] identifier in self?.applyTheme(identifier.theme) }
            .store(in: &observers)

        WorkspaceController.shared.$workspace
            .receive(on: RunLoop.main)
            .sink { [weak self] workspace in
                self?.browserViewController.setWorkspace(workspace)
                self?.highlightActiveDocument()
            }
            .store(in: &observers)

        highlightActiveDocument()

        // The tab group only exists once the window is on screen.
        DispatchQueue.main.async { [weak self] in
            self?.showTabBarIfHidden()
        }
    }

    /// One button. A writing application does not need a row of them, but the
    /// browser does need a control that can be clicked as well as a menu command.
    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "ParagraphToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        return toolbar
    }

    private func applyTheme(_ theme: Theme) {
        window?.appearance = theme.appearance
        splitViewController.splitView.needsDisplay = true
    }

    private func highlightActiveDocument() {
        guard let url = markdownDocument.fileURL else { return }
        browserViewController.selectItem(at: url)
    }

    // MARK: - Workspace Browser

    var isSidebarCollapsed: Bool { sidebarItem?.isCollapsed ?? true }

    @IBAction func toggleWorkspaceBrowser(_ sender: Any?) {
        setSidebarCollapsed(!sidebarItem.isCollapsed, propagateToTabGroup: true)
    }

    /// Animation is skipped when Reduce Motion is on, and can be skipped
    /// explicitly when the caller needs the new width to be true immediately.
    func setSidebarCollapsed(
        _ collapsed: Bool,
        propagateToTabGroup: Bool,
        animated: Bool = true
    ) {
        guard sidebarItem.isCollapsed != collapsed else { return }

        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            sidebarItem.animator().isCollapsed = collapsed
        } else {
            sidebarItem.isCollapsed = collapsed
        }

        guard propagateToTabGroup, let group = window?.tabGroup else { return }
        for sibling in group.windows where sibling !== window {
            (sibling.windowController as? DocumentWindowController)?
                .setSidebarCollapsed(collapsed, propagateToTabGroup: false, animated: animated)
        }
    }

    @IBAction func moveFocusToWorkspaceBrowser(_ sender: Any?) {
        if sidebarItem.isCollapsed {
            setSidebarCollapsed(false, propagateToTabGroup: true)
        }
        browserViewController.focusBrowser()
    }

    @IBAction func moveFocusToEditor(_ sender: Any?) {
        editorViewController.focusEditor()
    }

    @IBAction func openSelectedFileInTab(_ sender: Any?) {
        browserViewController.openSelectedInTab()
    }

    @IBAction func openSelectedFileInNewWindow(_ sender: Any?) {
        browserViewController.openSelectedInNewWindow()
    }

}

// MARK: - Menu state

extension DocumentWindowController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleWorkspaceBrowser(_:)):
            menuItem.state = isSidebarCollapsed ? .off : .on
            return true

        case #selector(openSelectedFileInTab(_:)), #selector(openSelectedFileInNewWindow(_:)):
            return browserViewController.selectedItem.map { !$0.isDirectory } ?? false

        default:
            return true
        }
    }
}

// MARK: - Window delegate

extension DocumentWindowController: NSWindowDelegate {

    /// Paragraph deliberately does not tell AppKit how big a zoomed window
    /// should be.
    ///
    /// Answering that question took over the whole toggle: AppKit decides
    /// whether a double-click zooms or restores by comparing the window
    /// against the size it would zoom to, and it keeps the pre-zoom frame
    /// itself. Supplying a fixed answer meant every double-click zoomed and
    /// none of them restored. There is nothing to implement here — the
    /// absence of an override is the fix, and a test asserts it stays absent.

    /// The tab bar stays visible even with a single tab.
    ///
    /// macOS hides it until a second tab exists, which means the row of chapters
    /// appears and disappears as you open and close them. Keeping it there makes
    /// the window a fixed shape to work in.
    func windowDidBecomeMain(_ notification: Notification) {
        showTabBarIfHidden()
    }

    func showTabBarIfHidden() {
        guard let window, let group = window.tabGroup, !group.isTabBarVisible else { return }
        window.toggleTabBar(nil)
    }
}

// MARK: - Toolbar

extension DocumentWindowController: NSToolbarDelegate {

    /// The standard sidebar button, and nothing else.
    ///
    /// A `.sidebarTrackingSeparator` was tried alongside it, glued to the
    /// split view's divider so the seam between browser and manuscript stayed
    /// visible in the toolbar. Its position depends on the divider's live
    /// geometry, though, and the divider itself moves — collapsing to nothing
    /// — when the sidebar is hidden. The result was the button visibly
    /// relocating each time the sidebar toggled, from just past the title to
    /// the toolbar's far trailing edge. A single fixed button leaves nothing
    /// for that geometry to disturb.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .flexibleSpace]
    }

    /// Standard identifiers still have to be vended explicitly. Without this
    /// method the toolbar has no way to create anything — including
    /// `.toggleSidebar` — so the button disappears entirely rather than merely
    /// losing its custom styling.
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == .toggleSidebar else { return nil }
        // A plain item with the standard identifier: AppKit fills in the
        // symbol, the accessibility label and the action itself.
        return NSToolbarItem(itemIdentifier: .toggleSidebar)
    }
}

// MARK: - Workspace browser delegate

extension DocumentWindowController: WorkspaceBrowserDelegate {

    func workspaceBrowser(
        _ browser: WorkspaceBrowserViewController,
        open url: URL,
        placement: OpenPlacement
    ) {
        // The browser names the window it belongs to; resolve it here so a
        // placement made before the window existed still lands in this group.
        let resolved: OpenPlacement
        switch placement {
        case .newTab: resolved = .newTab(in: window)
        case .newWindow: resolved = .newWindow
        }
        DocumentOpener.open(url: url, placement: resolved)
    }

    func workspaceBrowserDidRequestEditorFocus(_ browser: WorkspaceBrowserViewController) {
        editorViewController.focusEditor()
    }

    func workspaceBrowserDidRequestChooseFolder(_ browser: WorkspaceBrowserViewController) {
        WorkspaceController.shared.chooseWorkspace(from: window)
    }
}
