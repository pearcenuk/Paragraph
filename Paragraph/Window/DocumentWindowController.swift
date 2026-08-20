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

        splitViewController = NSSplitViewController()
        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
        // Lets macOS remember how wide the writer dragged the browser.
        splitViewController.splitView.autosaveName = "ParagraphSidebar"

        window?.contentViewController = splitViewController
        window?.toolbar = makeToolbar()

        WorkspaceController.shared.$workspace
            .receive(on: RunLoop.main)
            .sink { [weak self] workspace in
                self?.browserViewController.setWorkspace(workspace)
                self?.highlightActiveDocument()
            }
            .store(in: &observers)

        highlightActiveDocument()
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

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        // Tabs and the title bar show the document's name, never its path.
        displayName
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

// MARK: - Toolbar

extension DocumentWindowController: NSToolbarDelegate {
    private static let sidebarItemIdentifier = NSToolbarItem.Identifier("ParagraphToggleSidebar")

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.sidebarItemIdentifier, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.sidebarItemIdentifier, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.sidebarItemIdentifier else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = L10n.commandToggleWorkspaceBrowser
        item.paletteLabel = L10n.commandToggleWorkspaceBrowser
        item.toolTip = L10n.commandToggleWorkspaceBrowser
        item.image = NSImage(
            systemSymbolName: "sidebar.left",
            accessibilityDescription: L10n.commandToggleWorkspaceBrowser
        )
        item.target = self
        item.action = #selector(toggleWorkspaceBrowser(_:))
        item.isBordered = true
        return item
    }
}

// MARK: - Workspace browser delegate

extension DocumentWindowController: WorkspaceBrowserDelegate {

    func workspaceBrowser(_ browser: WorkspaceBrowserViewController, openInTab url: URL) {
        DocumentOpener.open(url: url, placement: .tab(in: window))
    }

    func workspaceBrowser(_ browser: WorkspaceBrowserViewController, openInNewWindow url: URL) {
        DocumentOpener.open(url: url, placement: .newWindow)
    }

    func workspaceBrowserDidRequestEditorFocus(_ browser: WorkspaceBrowserViewController) {
        editorViewController.focusEditor()
    }

    func workspaceBrowserDidRequestChooseFolder(_ browser: WorkspaceBrowserViewController) {
        WorkspaceController.shared.chooseWorkspace(from: window)
    }
}
