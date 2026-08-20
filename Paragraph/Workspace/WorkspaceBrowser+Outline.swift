import AppKit

// MARK: - Data source

extension WorkspaceBrowserViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        children(of: item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        children(of: item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? WorkspaceItem)?.isDirectory ?? false
    }

    private func children(of item: Any?) -> [WorkspaceItem] {
        guard let item = item as? WorkspaceItem else { return workspace?.rootItems ?? [] }
        return item.children
    }

    /// Files can be dragged out of the browser onto an editor, a tab, or another
    /// application, because they are just files.
    func outlineView(
        _ outlineView: NSOutlineView,
        pasteboardWriterForItem item: Any
    ) -> NSPasteboardWriting? {
        guard let item = item as? WorkspaceItem, !item.isDirectory else { return nil }
        return item.url as NSURL
    }
}

// MARK: - Delegate

extension WorkspaceBrowserViewController: NSOutlineViewDelegate {

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let item = item as? WorkspaceItem else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("WorkspaceCell")

        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? Self.makeCell(identifier: identifier)

        cell.textField?.stringValue = item.name
        cell.imageView?.image = icon(for: item)

        // Availability is never signalled by colour alone: an unavailable item
        // gets a different symbol and an accessibility description.
        switch item.cloudStatus {
        case .local:
            cell.textField?.textColor = .labelColor
            cell.setAccessibilityLabel(item.name)
        case .downloading:
            cell.textField?.textColor = .secondaryLabelColor
            cell.setAccessibilityLabel("\(item.name), \(L10n.itemDownloading)")
        case .notDownloaded:
            cell.textField?.textColor = .secondaryLabelColor
            cell.setAccessibilityLabel("\(item.name), \(L10n.itemNotDownloaded)")
        }
        return cell
    }

    private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        textField.font = .systemFont(ofSize: 12)

        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func icon(for item: WorkspaceItem) -> NSImage? {
        let name: String
        switch (item.isDirectory, item.cloudStatus) {
        case (true, _): name = "folder"
        case (false, .local): name = "doc.text"
        case (false, .downloading): name = "arrow.down.circle"
        case (false, .notDownloaded): name = "icloud.and.arrow.down"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    /// Return opens the selection; Escape hands focus back to the manuscript.
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool { true }
}

// MARK: - Keyboard

/// A thin subclass so Return and Escape mean what a writer expects inside a file
/// list, without disturbing the arrow-key navigation `NSOutlineView` already has.
final class WorkspaceOutlineView: NSOutlineView {
    weak var keyDelegate: WorkspaceBrowserViewController?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:                                    // Return, Enter
            if event.modifierFlags.contains(.shift) {
                keyDelegate?.openSelectedInNewWindow()
            } else {
                keyDelegate?.openSelectedInTab()
            }
        case 53:                                        // Escape
            keyDelegate?.returnFocusToEditor()
        default:
            super.keyDown(with: event)
        }
    }
}
