import AppKit

/// Where a file should appear when it is opened.
enum OpenPlacement {
    /// As a tab in the given window's tab group, or a new window if there is none.
    case newTab(in: NSWindow?)
    case newWindow
}

/// Opens files without ever creating a second copy of one.
///
/// `NSDocumentController` guarantees there is at most one `MarkdownDocument`
/// per URL. Opening a file that is already open therefore adds another *view* of
/// the same document — sharing its text storage and its undo stack — rather than
/// a rival copy that could overwrite the first one's work.
enum DocumentOpener {

    static func open(url: URL, placement: OpenPlacement) {
        let controller = NSDocumentController.shared

        if let existing = controller.document(for: url) as? MarkdownDocument {
            place(existing, placement: placement)
            return
        }

        prepareCloudFile(at: url)

        controller.openDocument(withContentsOf: url, display: false) { document, _, error in
            if let error {
                presentOpenError(error, url: url)
                return
            }
            guard let document = document as? MarkdownDocument else { return }
            place(document, placement: placement)
        }
    }

    /// Asks the system to fetch a file that iCloud has not brought down yet.
    /// The editor is never blocked waiting for it; the file simply opens when it
    /// arrives.
    private static func prepareCloudFile(at url: URL) {
        let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey,
                                                       .ubiquitousItemDownloadingStatusKey])
        guard values?.isUbiquitousItem == true,
              values?.ubiquitousItemDownloadingStatus == .notDownloaded
        else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    static func place(_ document: MarkdownDocument, placement: OpenPlacement) {
        switch placement {
        case .newTab(let requestedWindow):
            let target = requestedWindow ?? NSApp.mainWindow

            // Never open a second tab on a file this window group already shows.
            if let existing = windowController(for: document, inGroupOf: target) {
                existing.window?.makeKeyAndOrderFront(nil)
                return
            }

            let controller = attachNewWindowController(to: document)
            guard let window = controller.window else { return }

            if let target, target.tabbingIdentifier == window.tabbingIdentifier, target !== window {
                target.addTabbedWindow(window, ordered: .above)
            }
            window.makeKeyAndOrderFront(nil)

            // A blank untitled tab is scaffolding rather than work, and AppKit
            // clears one away when a real document opens. Do the same here so it
            // does not accumulate beside every file the writer opens.
            if let target, target !== window {
                closeIfEmptyUntitled(target)
            }

        case .newWindow:
            // An explicit request for a window is honoured even if the document
            // is already showing somewhere else.
            let controller = attachNewWindowController(to: document)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    /// Clears away an untitled document that has never been typed in.
    ///
    /// Nothing else is ever closed: opening a file adds a tab, and a document
    /// with any content at all — saved or not — keeps its place.
    private static func closeIfEmptyUntitled(_ window: NSWindow) {
        guard let controller = window.windowController as? DocumentWindowController else { return }
        let document = controller.markdownDocument
        guard document.windowControllers.count <= 1,
              document.fileURL == nil,
              document.textStorage.length == 0,
              !document.isDocumentEdited
        else { return }
        document.close()
    }

    private static func attachNewWindowController(
        to document: MarkdownDocument
    ) -> DocumentWindowController {
        if let unused = document.windowControllers.first as? DocumentWindowController,
           unused.window?.isVisible == false,
           document.windowControllers.count == 1 {
            // The controller `makeWindowControllers` created but never showed.
            return unused
        }
        let controller = DocumentWindowController(markdownDocument: document)
        document.addWindowController(controller)
        return controller
    }

    private static func windowController(
        for document: MarkdownDocument,
        inGroupOf target: NSWindow?
    ) -> NSWindowController? {
        document.windowControllers.first { controller in
            guard let window = controller.window else { return false }
            guard let target else { return true }
            if window === target { return true }
            if let group = target.tabGroup, group.windows.contains(window) { return true }
            return false
        }
    }

    // MARK: - Errors

    /// A file that has moved, been renamed or gone offline is reported plainly.
    /// Paragraph never invents a replacement file to paper over the gap.
    private static func presentOpenError(_ error: Error, url: URL) {
        let alert = NSAlert()
        alert.messageText = L10n.missingFileTitle(url.lastPathComponent)
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.ok)
        alert.runModal()
    }
}
