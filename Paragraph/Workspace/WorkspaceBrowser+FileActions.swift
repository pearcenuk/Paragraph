import AppKit

/// The contextual menu and the file operations behind it.
///
/// These are the operations a writer actually needs on a manuscript file. They
/// are performed through file coordination so that iCloud Drive and any other
/// editor watching the folder see them properly, and the destructive one asks
/// first.
extension WorkspaceBrowserViewController {

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: L10n.contextNewFile,
                     action: #selector(contextNewFile), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.commandOpenInTab,
                     action: #selector(contextOpenInTab), keyEquivalent: "")
        menu.addItem(withTitle: L10n.commandOpenInNewWindow,
                     action: #selector(contextOpenInNewWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.contextRename,
                     action: #selector(contextRename), keyEquivalent: "")
        menu.addItem(withTitle: L10n.contextRevealInFinder,
                     action: #selector(contextRevealInFinder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.contextMoveToTrash,
                     action: #selector(contextMoveToTrash), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    /// The contextual menu acts on the row that was right-clicked, which is not
    /// necessarily the row that was already selected.
    private var contextItem: WorkspaceItem? {
        guard let outlineView = clickedOutlineView else { return selectedItem }
        let row = outlineView.clickedRow
        guard row >= 0 else { return selectedItem }
        return outlineView.item(atRow: row) as? WorkspaceItem
    }

    /// Creates a file beside what was right-clicked.
    ///
    /// Right-clicking a folder puts the file inside it; right-clicking a file
    /// puts it alongside; right-clicking nothing puts it at the top of the
    /// workspace. That is where a writer means, in each case.
    @objc private func contextNewFile() {
        guard let workspace, let window = view.window else { return }
        let folder = destinationFolder(for: contextItem, in: workspace)

        let alert = NSAlert()
        alert.messageText = L10n.newFileTitle
        alert.informativeText = L10n.newFileInFolder(folder.lastPathComponent)
        alert.addButton(withTitle: L10n.newFileButton)
        alert.addButton(withTitle: L10n.cancel)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = L10n.newFileDefaultName
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.createFile(named: field.stringValue, in: folder)
        }
    }

    private func destinationFolder(for item: WorkspaceItem?, in workspace: Workspace) -> URL {
        guard let item else { return workspace.rootURL }
        return item.isDirectory ? item.url : item.url.deletingLastPathComponent()
    }

    private func createFile(named typed: String, in folder: URL) {
        guard let name = Workspace.normalisedNewFileName(typed) else { return }
        let destination = folder.appendingPathComponent(name)

        guard !FileManager.default.fileExists(atPath: destination.path) else {
            presentExistingFile(named: name)
            return
        }

        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: destination, options: .forReplacing, error: &coordinationError
        ) { url in
            do {
                // Empty, not a template. A blank page is the point.
                try Data().write(to: url, options: .withoutOverwriting)
            } catch {
                writeError = error
            }
        }
        if let error = writeError ?? coordinationError {
            presentFileError(error)
            return
        }

        workspace?.refresh()
        // The scan publishes on the main queue, so wait for the row to exist
        // before selecting it and handing the writer a cursor.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.selectItem(at: destination)
            self.delegate?.workspaceBrowser(
                self, open: destination, placement: .newTab(in: self.view.window)
            )
        }
    }

    private func presentExistingFile(named name: String) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = L10n.newFileExists(name)
        alert.informativeText = L10n.newFileExistsDetail
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.ok)
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

    @objc private func contextOpenInTab() {
        guard let item = contextItem, !item.isDirectory else { return }
        delegate?.workspaceBrowser(self, open: item.url, placement: .newTab(in: view.window))
    }

    @objc private func contextOpenInNewWindow() {
        guard let item = contextItem, !item.isDirectory else { return }
        delegate?.workspaceBrowser(self, open: item.url, placement: .newWindow)
    }

    @objc private func contextRevealInFinder() {
        guard let item = contextItem else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    @objc private func contextRename() {
        guard let item = contextItem, let window = view.window else { return }

        let alert = NSAlert()
        alert.messageText = L10n.renameTitle
        alert.addButton(withTitle: L10n.renameButton)
        alert.addButton(withTitle: L10n.cancel)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = item.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty, newName != item.name else { return }
            self?.rename(item, to: newName)
        }
    }

    private func rename(_ item: WorkspaceItem, to newName: String) {
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        var coordinationError: NSError?
        var moveError: Error?

        NSFileCoordinator().coordinate(
            writingItemAt: item.url, options: .forMoving,
            writingItemAt: destination, options: .forReplacing,
            error: &coordinationError
        ) { source, target in
            do {
                try FileManager.default.moveItem(at: source, to: target)
            } catch {
                moveError = error
            }
        }
        if let error = moveError ?? coordinationError {
            presentFileError(error)
        }
        workspace?.refresh()
    }

    @objc private func contextMoveToTrash() {
        guard let item = contextItem, let window = view.window else { return }

        // Destructive, so it asks. The wording says where the file goes, because
        // "are you sure?" tells the writer nothing.
        let alert = NSAlert()
        alert.messageText = L10n.trashConfirmTitle(item.name)
        alert.informativeText = L10n.trashConfirmDetail
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.trashConfirmButton)
        alert.addButton(withTitle: L10n.cancel)

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.moveToTrash(item)
        }
    }

    private func moveToTrash(_ item: WorkspaceItem) {
        var coordinationError: NSError?
        var trashError: Error?

        NSFileCoordinator().coordinate(
            writingItemAt: item.url, options: .forDeleting, error: &coordinationError
        ) { url in
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                trashError = error
            }
        }
        if let error = trashError ?? coordinationError {
            presentFileError(error)
        }
        workspace?.refresh()
    }

    private func presentFileError(_ error: Error) {
        guard let window = view.window else { return }
        NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
    }
}

// MARK: - Menu validation

extension WorkspaceBrowserViewController: NSMenuDelegate {

    /// A folder row should not offer "Open in Tab", and an empty click should
    /// not offer anything at all.
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.autoenablesItems = false
        let item = clickedItem
        let isFile = item.map { !$0.isDirectory } ?? false
        let exists = item != nil

        for menuItem in menu.items where !menuItem.isSeparatorItem {
            switch menuItem.title {
            case L10n.contextNewFile:
                menuItem.isEnabled = workspace != nil
            case L10n.commandOpenInTab, L10n.commandOpenInNewWindow:
                menuItem.isEnabled = isFile
            default:
                menuItem.isEnabled = exists
            }
        }
    }

    var clickedOutlineView: NSOutlineView? {
        (view.subviews.first as? NSScrollView)?.documentView as? NSOutlineView
    }

    var clickedItem: WorkspaceItem? {
        guard let outlineView = clickedOutlineView else { return nil }
        let row = outlineView.clickedRow
        guard row >= 0 else { return selectedItem }
        return outlineView.item(atRow: row) as? WorkspaceItem
    }
}
