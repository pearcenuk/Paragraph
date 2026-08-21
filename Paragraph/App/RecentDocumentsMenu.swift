import AppKit

/// Fills the Open Recent submenu from `NSDocumentController`.
///
/// AppKit's automatic version of this menu is only wired up when the menu comes
/// from a nib. Paragraph builds its menus in code, so the list is assembled here
/// through public API instead.
final class RecentDocumentsMenuDelegate: NSObject, NSMenuDelegate {
    static let shared = RecentDocumentsMenuDelegate()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let urls = NSDocumentController.shared.recentDocumentURLs
        for url in urls {
            let item = NSMenuItem(
                title: url.lastPathComponent,
                action: #selector(openRecentDocument(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = url
            item.image = NSWorkspace.shared.icon(forFile: url.path)
            item.image?.size = NSSize(width: 16, height: 16)
            item.toolTip = url.path
            menu.addItem(item)
        }

        guard !urls.isEmpty else { return }
        menu.addItem(.separator())
        let clear = NSMenuItem(
            title: L10n.clearMenu,
            action: #selector(NSDocumentController.clearRecentDocuments(_:)),
            keyEquivalent: ""
        )
        clear.target = NSDocumentController.shared
        menu.addItem(clear)
    }

    @objc private func openRecentDocument(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        DocumentOpener.open(url: url, placement: .newTab(in: NSApp.mainWindow))
    }
}
