import AppKit
import Combine

protocol WorkspaceBrowserDelegate: AnyObject {
    func workspaceBrowser(_ browser: WorkspaceBrowserViewController, openInTab url: URL)
    func workspaceBrowser(_ browser: WorkspaceBrowserViewController, openInNewWindow url: URL)
    func workspaceBrowserDidRequestEditorFocus(_ browser: WorkspaceBrowserViewController)
    func workspaceBrowserDidRequestChooseFolder(_ browser: WorkspaceBrowserViewController)
}

/// Paragraph's own file navigator.
///
/// This is deliberately an `NSOutlineView` rather than a SwiftUI `List`. The
/// browser has to do a lot that SwiftUI cannot express on this deployment
/// target: arrow-key navigation, Return to open, a drag source, disclosure
/// triangles, a contextual menu, and correct VoiceOver behaviour for a tree.
/// `NSOutlineView` provides all of it, and Paragraph is not in the business of
/// re-implementing mature system controls.
///
/// It is a file browser and only a file browser. There is nothing here to tag,
/// rate, group, or plan with.
final class WorkspaceBrowserViewController: NSViewController {

    weak var delegate: WorkspaceBrowserDelegate?

    private(set) var workspace: Workspace?
    private var outlineView: WorkspaceOutlineView!
    private var scrollView: NSScrollView!
    private var emptyStateView: NSView?
    private var observers: Set<AnyCancellable> = []
    /// Kept apart from `observers` so replacing the workspace does not tear down
    /// the theme subscription along with it.
    private var workspaceObserver: AnyCancellable?
    /// A selection asked for before the view existed, applied once it does.
    private var pendingSelection: URL?

    // MARK: - View

    override func loadView() {
        outlineView = WorkspaceOutlineView()
        outlineView.keyDelegate = self
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.allowsMultipleSelection = false
        outlineView.focusRingType = .default
        outlineView.indentationPerLevel = 14
        outlineView.autosaveExpandedItems = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)
        outlineView.setAccessibilityLabel(L10n.workspaceBrowser)
        outlineView.setDraggingSourceOperationMask([.copy, .link], forLocal: false)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        view = container

        outlineView.menu = makeContextMenu()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme(Preferences.shared.currentTheme)
        reloadIfLoaded()

        Preferences.shared.$theme
            .receive(on: RunLoop.main)
            .sink { [weak self] identifier in self?.applyTheme(identifier.theme) }
            .store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSOutlineView.itemDidExpandNotification, object: outlineView)
            .merge(with: NotificationCenter.default
                .publisher(for: NSOutlineView.itemDidCollapseNotification, object: outlineView))
            .sink { [weak self] _ in self?.rememberExpandedFolders() }
            .store(in: &observers)
    }

    private func applyTheme(_ theme: Theme) {
        guard isViewLoaded else { return }
        if let background = theme.sidebarBackground {
            scrollView.drawsBackground = true
            scrollView.backgroundColor = background
            outlineView.backgroundColor = background
        } else {
            scrollView.drawsBackground = false
            outlineView.backgroundColor = .clear
        }
        view.appearance = theme.appearance
        outlineView.reloadData()
        restoreExpandedFolders()
    }

    // MARK: - Workspace

    /// Safe to call before the view is loaded: a window controller configures
    /// its browser while assembling the window, which is earlier than that.
    func setWorkspace(_ workspace: Workspace?) {
        workspaceObserver = nil
        self.workspace = workspace

        guard let workspace else {
            reloadIfLoaded()
            return
        }
        workspaceObserver = workspace.$rootItems
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isViewLoaded else { return }
                let selected = self.selectedItem?.url
                self.outlineView.reloadData()
                self.restoreExpandedFolders()
                if let selected { self.selectItem(at: selected) }
                self.updateEmptyState()
            }
        reloadIfLoaded()
    }

    private func reloadIfLoaded() {
        guard isViewLoaded else { return }
        outlineView.reloadData()
        restoreExpandedFolders()
        updateEmptyState()
        if let pendingSelection {
            self.pendingSelection = nil
            selectItem(at: pendingSelection)
        }
    }

    private var rootItems: [WorkspaceItem] { workspace?.rootItems ?? [] }

    // MARK: - Empty state

    private func updateEmptyState() {
        guard isViewLoaded else { return }
        emptyStateView?.removeFromSuperview()
        emptyStateView = nil

        let message: String?
        if workspace == nil {
            message = L10n.noWorkspace
        } else if workspace?.isAvailable == false {
            message = L10n.workspaceUnavailable
        } else if rootItems.isEmpty {
            message = L10n.emptyWorkspace
        } else {
            message = nil
        }
        guard let message else { return }

        let label = NSTextField(labelWithString: message)
        label.alignment = .center
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        if workspace == nil {
            let button = NSButton(
                title: L10n.chooseWorkspace,
                target: self,
                action: #selector(chooseFolder)
            )
            button.bezelStyle = .rounded
            stack.addArrangedSubview(button)
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32)
        ])
        emptyStateView = stack
    }

    @objc private func chooseFolder() {
        delegate?.workspaceBrowserDidRequestChooseFolder(self)
    }

    // MARK: - Selection

    var selectedItem: WorkspaceItem? {
        let row = outlineView.selectedRow
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row) as? WorkspaceItem
    }

    /// Highlights the document the writer is currently editing.
    func selectItem(at url: URL) {
        guard isViewLoaded else {
            pendingSelection = url
            return
        }
        guard let item = findItem(at: url, in: rootItems) else { return }
        expandParents(of: item)
        let row = outlineView.row(forItem: item)
        guard row >= 0 else { return }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
    }

    private func findItem(at url: URL, in items: [WorkspaceItem]) -> WorkspaceItem? {
        for item in items {
            if item.url.standardizedFileURL == url.standardizedFileURL { return item }
            if item.isDirectory, let found = findItem(at: url, in: item.children) { return found }
        }
        return nil
    }

    private func expandParents(of target: WorkspaceItem) {
        func expandPath(in items: [WorkspaceItem]) -> Bool {
            for item in items where item.isDirectory {
                if item.children.contains(target) || expandPath(in: item.children) {
                    outlineView.expandItem(item)
                    return true
                }
            }
            return false
        }
        _ = expandPath(in: rootItems)
    }

    func returnFocusToEditor() {
        delegate?.workspaceBrowserDidRequestEditorFocus(self)
    }

    func focusBrowser() {
        guard isViewLoaded else { return }
        view.window?.makeFirstResponder(outlineView)
        if outlineView.selectedRow < 0, outlineView.numberOfRows > 0 {
            outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Expanded folders

    private func rememberExpandedFolders() {
        guard isViewLoaded else { return }
        var expanded: [String] = []
        for row in 0..<outlineView.numberOfRows {
            if let item = outlineView.item(atRow: row) as? WorkspaceItem,
               item.isDirectory,
               outlineView.isItemExpanded(item) {
                expanded.append(item.relativePath)
            }
        }
        Preferences.shared.expandedFolders = expanded
    }

    private func restoreExpandedFolders() {
        guard isViewLoaded else { return }
        let wanted = Set(Preferences.shared.expandedFolders)
        guard !wanted.isEmpty else { return }

        func expand(_ items: [WorkspaceItem]) {
            for item in items where item.isDirectory {
                if wanted.contains(item.relativePath) {
                    outlineView.expandItem(item)
                    expand(item.children)
                }
            }
        }
        expand(rootItems)
    }

    // MARK: - Opening

    @objc private func handleDoubleClick() {
        guard let item = selectedItem else { return }
        if item.isDirectory {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        } else {
            delegate?.workspaceBrowser(self, openInTab: item.url)
        }
    }

    func openSelectedInTab() {
        guard let item = selectedItem, !item.isDirectory else { return }
        delegate?.workspaceBrowser(self, openInTab: item.url)
    }

    func openSelectedInNewWindow() {
        guard let item = selectedItem, !item.isDirectory else { return }
        delegate?.workspaceBrowser(self, openInNewWindow: item.url)
    }
}
