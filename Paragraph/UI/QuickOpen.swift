import AppKit
import SwiftUI
import Combine

/// Filters the current workspace's files as the writer types.
///
/// This is Quick Open, not a command palette. It finds files in the workspace
/// and does nothing else, and it never looks outside that folder.
final class QuickOpenModel: ObservableObject {
    @Published var query = "" { didSet { updateResults() } }
    @Published private(set) var results: [WorkspaceItem] = []
    @Published var selectedIndex = 0

    private var allFiles: [WorkspaceItem] = []

    func reload(from workspace: Workspace?) {
        allFiles = workspace?.allFiles ?? []
        query = ""
        updateResults()
    }

    private func updateResults() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = Array(allFiles.prefix(50))
            selectedIndex = 0
            return
        }

        let scored = allFiles.compactMap { item -> (WorkspaceItem, Int)? in
            guard let score = Self.score(item, query: trimmed) else { return nil }
            return (item, score)
        }
        results = scored
            .sorted {
                $0.1 != $1.1
                    ? $0.1 < $1.1
                    : $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
            }
            .prefix(50)
            .map(\.0)
        selectedIndex = 0
    }

    /// Lower is better: a name that starts with the query beats one that merely
    /// contains it, which beats a match only in the folder path.
    private static func score(_ item: WorkspaceItem, query: String) -> Int? {
        let name = item.name.lowercased()
        let path = item.relativePath.lowercased()
        let needle = query.lowercased()

        if name.hasPrefix(needle) { return 0 }
        if name.contains(needle) { return 1 }
        if path.contains(needle) { return 2 }
        return isSubsequence(needle, of: name) ? 3 : nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var index = haystack.startIndex
        for character in needle {
            guard let found = haystack[index...].firstIndex(of: character) else { return false }
            index = haystack.index(after: found)
        }
        return true
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + offset), results.count - 1)
    }

    var selectedItem: WorkspaceItem? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }
}

struct QuickOpenView: View {
    @ObservedObject var model: QuickOpenModel
    let theme: Theme
    var onOpen: (WorkspaceItem, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField(L10n.quickOpenPlaceholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityLabel(L10n.quickOpenPlaceholder)

            Divider()

            if model.results.isEmpty {
                Text(L10n.quickOpenNoMatches)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                                QuickOpenRow(
                                    item: item,
                                    isSelected: index == model.selectedIndex,
                                    theme: theme
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.selectedIndex = index
                                    onOpen(item, false)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: model.selectedIndex) { _ in
                        if let item = model.selectedItem {
                            proxy.scrollTo(item.id)
                        }
                    }
                }
            }

            Divider()
            Text(L10n.quickOpenHint)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .background(Color(nsColor: theme.editorBackground))
    }
}

private struct QuickOpenRow: View {
    let item: WorkspaceItem
    let isSelected: Bool
    let theme: Theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 13))
                if item.relativePath != item.name {
                    Text((item.relativePath as NSString).deletingLastPathComponent)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A floating panel, dismissed with Escape, that never becomes a window the
/// writer has to manage.
final class QuickOpenPanelController {
    static let shared = QuickOpenPanelController()

    private var panel: NSPanel?
    private var keyMonitor: Any?
    private let model = QuickOpenModel()

    private init() {}

    func show(relativeTo parent: NSWindow?) {
        model.reload(from: WorkspaceController.shared.workspace)

        if panel == nil { panel = makePanel() }
        guard let panel else { return }

        position(panel, relativeTo: parent)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let view = QuickOpenView(
            model: model,
            theme: Preferences.shared.currentTheme,
            onOpen: { [weak self] item, newWindow in self?.open(item, inNewWindow: newWindow) }
        )
        let hosting = NSHostingView(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 200),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        panel.appearance = Preferences.shared.currentTheme.appearance
        return panel
    }

    private func position(_ panel: NSPanel, relativeTo parent: NSWindow?) {
        let screenFrame = (parent?.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let size = NSSize(width: 560, height: 380)
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2 + screenFrame.height * 0.15
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// Arrow keys and Return have to be intercepted before the text field sees
    /// them, which a local monitor does without subclassing the field.
    private func installKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }

            switch event.keyCode {
            case 125:                                       // Down arrow
                self.model.moveSelection(by: 1)
                return nil
            case 126:                                       // Up arrow
                self.model.moveSelection(by: -1)
                return nil
            case 36, 76:                                    // Return, Enter
                if let item = self.model.selectedItem {
                    self.open(item, inNewWindow: event.modifierFlags.contains(.shift))
                }
                return nil
            case 53:                                        // Escape
                self.close()
                return nil
            default:
                return event
            }
        }
    }

    private func open(_ item: WorkspaceItem, inNewWindow: Bool) {
        close()
        DocumentOpener.open(
            url: item.url,
            placement: inNewWindow ? .newWindow : .tab(in: NSApp.mainWindow)
        )
    }
}
