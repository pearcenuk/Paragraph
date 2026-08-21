import AppKit

/// Captures and rebuilds the writer's session: which windows were open, which
/// tabs were in them, and roughly where the cursor was in each.
enum SessionRestorer {

    // MARK: - Capture

    static func captureCurrentSession() -> SessionState {
        var state = SessionState()
        var seenGroups: [ObjectIdentifier] = []

        for window in NSApp.windows {
            guard let controller = window.windowController as? DocumentWindowController,
                  window.isVisible
            else { continue }

            // Each tab group becomes one restored window.
            let groupWindows: [NSWindow]
            if let group = window.tabGroup {
                let key = ObjectIdentifier(group)
                if seenGroups.contains(key) { continue }
                seenGroups.append(key)
                groupWindows = group.windows
            } else {
                groupWindows = [window]
            }

            // An unsaved document has no file to record, so it is left out.
            // The active index must be counted against what actually gets
            // written, not against every window in the group, or restoring will
            // select the wrong tab.
            let recorded: [(window: NSWindow, tab: TabSession)] = groupWindows.compactMap { tabWindow in
                guard let tabController = tabWindow.windowController as? DocumentWindowController,
                      let url = tabController.markdownDocument.fileURL
                else { return nil }

                let editor = tabController.editorViewController
                return (
                    tabWindow,
                    TabSession(
                        bookmark: SessionStore.bookmark(for: url),
                        path: url.path,
                        selectionLocation: editor.selectedRange.location,
                        scrollFraction: editor.scrollFraction
                    )
                )
            }
            let tabs = recorded.map(\.tab)
            guard !tabs.isEmpty else { continue }

            let activeIndex = window.tabGroup?.selectedWindow
                .flatMap { selected in recorded.firstIndex { $0.window === selected } } ?? 0

            state.windows.append(
                WindowSession(
                    frame: NSStringFromRect(groupWindows.first?.frame ?? window.frame),
                    sidebarCollapsed: controller.isSidebarCollapsed,
                    activeTabIndex: activeIndex,
                    tabs: tabs
                )
            )
        }
        return state
    }

    // MARK: - Restore

    /// Rebuilds the session. Returns `false` if nothing could be restored, so
    /// the caller can fall back to its normal launch behaviour.
    @discardableResult
    static func restore(_ state: SessionState) -> Bool {
        var restoredAnything = false
        var missing: [String] = []

        for windowSession in state.windows {
            var windowsInGroup: [NSWindow] = []

            for tab in windowSession.tabs {
                guard let url = resolve(tab) else {
                    missing.append((tab.path as NSString).lastPathComponent)
                    continue
                }
                guard let controller = openSynchronously(url: url) else {
                    missing.append(url.lastPathComponent)
                    continue
                }
                guard let window = controller.window else { continue }

                if let first = windowsInGroup.first, first !== window {
                    first.addTabbedWindow(window, ordered: .above)
                }
                windowsInGroup.append(window)
                restoredAnything = true

                controller.setSidebarCollapsed(windowSession.sidebarCollapsed,
                                               propagateToTabGroup: false)
                let editor = controller.editorViewController
                // `loadViewIfNeeded()` is macOS 14; touching `view` is the
                // equivalent on this deployment target.
                _ = editor.view
                editor.selectedRange = NSRange(location: tab.selectionLocation, length: 0)
                DispatchQueue.main.async {
                    editor.scrollFraction = tab.scrollFraction
                }
            }

            if let first = windowsInGroup.first {
                first.setFrame(NSRectFromString(windowSession.frame), display: true)
                let index = min(max(0, windowSession.activeTabIndex), windowsInGroup.count - 1)
                windowsInGroup[index].makeKeyAndOrderFront(nil)
            }
        }

        if !missing.isEmpty { reportMissingFiles(missing) }
        return restoredAnything
    }

    private static func resolve(_ tab: TabSession) -> URL? {
        if let bookmark = tab.bookmark,
           let url = SessionStore.resolve(bookmark),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let fallback = URL(fileURLWithPath: tab.path)
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    /// Restoration needs the window controller straight away in order to build
    /// the tab group in the right order, so this waits for each document.
    private static func openSynchronously(url: URL) -> DocumentWindowController? {
        let controller = NSDocumentController.shared

        if let existing = controller.document(for: url) as? MarkdownDocument,
           let windowController = existing.windowControllers.first as? DocumentWindowController {
            return windowController
        }

        var result: DocumentWindowController?
        let semaphore = DispatchSemaphore(value: 0)

        controller.openDocument(withContentsOf: url, display: false) { document, _, _ in
            if let document = document as? MarkdownDocument {
                let windowController = DocumentWindowController(markdownDocument: document)
                document.addWindowController(windowController)
                _ = windowController.window
                result = windowController
            }
            semaphore.signal()
        }

        // `openDocument` calls back on the main queue; pump it rather than block.
        while semaphore.wait(timeout: .now()) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        return result
    }

    /// A file that has moved or been deleted is named, not silently forgotten
    /// and never recreated.
    private static func reportMissingFiles(_ names: [String]) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = names.count == 1
            ? L10n.missingFileTitle(names[0])
            : L10n.missingFileTitle(names.joined(separator: ", "))
        alert.informativeText = L10n.missingFileDetail
        alert.addButton(withTitle: L10n.missingFileRemove)
        alert.addButton(withTitle: L10n.missingFileLocate)

        if alert.runModal() == .alertSecondButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = true
            if panel.runModal() == .OK {
                for url in panel.urls {
                    DocumentOpener.open(url: url, placement: .tab(in: NSApp.mainWindow))
                }
            }
        }
    }
}
