import AppKit
import Combine

/// Whether a file is actually here, or still in iCloud.
enum CloudStatus {
    case local
    case downloading
    case notDownloaded

    var isAvailable: Bool { self == .local }
}

/// One file or folder in the workspace.
final class WorkspaceItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let relativePath: String
    var children: [WorkspaceItem]
    var cloudStatus: CloudStatus

    init(
        url: URL,
        name: String,
        isDirectory: Bool,
        relativePath: String,
        children: [WorkspaceItem] = [],
        cloudStatus: CloudStatus = .local
    ) {
        self.id = relativePath
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.relativePath = relativePath
        self.children = children
        self.cloudStatus = cloudStatus
    }

    static func == (lhs: WorkspaceItem, rhs: WorkspaceItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Every file at or below this item, depth first.
    var allFiles: [WorkspaceItem] {
        isDirectory ? children.flatMap(\.allFiles) : [self]
    }
}

/// The folder the writer is working in.
///
/// A workspace is a folder and nothing more. There is no index, no database, no
/// metadata and no tags — deleting Paragraph would leave the writer with exactly
/// the folder of Markdown files they started with.
///
/// Access is held through a security-scoped bookmark so that a sandboxed
/// Paragraph can reopen an iCloud Drive folder on a later launch without asking
/// the writer to choose it again.
final class Workspace: ObservableObject {

    static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

    /// Guards against a mistakenly chosen home folder becoming a filesystem
    /// crawl. Paragraph only ever looks inside the folder it was given.
    private static let maximumDepth = 12
    private static let maximumItems = 5_000

    let rootURL: URL
    @Published private(set) var rootItems: [WorkspaceItem] = []
    @Published private(set) var isAvailable = true

    private var isAccessing = false
    private var watcher: DirectoryWatcher?

    var name: String { rootURL.lastPathComponent }

    init?(url: URL, startAccessing: Bool = true) {
        self.rootURL = url
        if startAccessing {
            isAccessing = url.startAccessingSecurityScopedResource()
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            stopAccessing()
            return nil
        }
        refresh()
        startWatching()
    }

    deinit {
        watcher?.stop()
        stopAccessing()
    }

    private func stopAccessing() {
        if isAccessing {
            rootURL.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    // MARK: - Scanning

    func refresh() {
        var budget = Self.maximumItems
        let items = Self.scan(rootURL, relativeTo: "", depth: 0, budget: &budget)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rootItems = items
            self.isAvailable = FileManager.default.fileExists(atPath: self.rootURL.path)
        }
    }

    private static func scan(
        _ directory: URL,
        relativeTo prefix: String,
        depth: Int,
        budget: inout Int
    ) -> [WorkspaceItem] {
        guard depth < maximumDepth, budget > 0 else { return [] }

        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isPackageKey, .isHiddenKey,
            .ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey
        ]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var folders: [WorkspaceItem] = []
        var files: [WorkspaceItem] = []

        for url in contents {
            guard budget > 0 else { break }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isHidden == true { continue }

            let name = url.lastPathComponent
            let relative = prefix.isEmpty ? name : "\(prefix)/\(name)"

            if values?.isDirectory == true, values?.isPackage != true {
                budget -= 1
                var children = scan(url, relativeTo: relative, depth: depth + 1, budget: &budget)
                // A folder with nothing Paragraph can open is noise in a writing
                // application, so it is not listed.
                guard !children.isEmpty else { continue }
                children.sort(by: order)
                folders.append(
                    WorkspaceItem(
                        url: url, name: name, isDirectory: true,
                        relativePath: relative, children: children
                    )
                )
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                budget -= 1
                files.append(
                    WorkspaceItem(
                        url: url, name: name, isDirectory: false,
                        relativePath: relative,
                        cloudStatus: cloudStatus(from: values)
                    )
                )
            }
        }

        folders.sort(by: order)
        files.sort(by: order)
        return folders + files
    }

    private static func order(_ lhs: WorkspaceItem, _ rhs: WorkspaceItem) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func cloudStatus(from values: URLResourceValues?) -> CloudStatus {
        guard values?.isUbiquitousItem == true else { return .local }
        switch values?.ubiquitousItemDownloadingStatus {
        case .some(.current), .some(.downloaded): return .local
        case .some(.notDownloaded): return .notDownloaded
        default: return .downloading
        }
    }

    /// All openable files, used by Quick Open. Never leaves the workspace.
    var allFiles: [WorkspaceItem] { rootItems.flatMap(\.allFiles) }

    func item(at url: URL) -> WorkspaceItem? {
        allFiles.first { $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    // MARK: - Watching

    /// The browser must reflect files added, removed or renamed by anything
    /// else — Finder, another editor, or iCloud Drive syncing a change down.
    private func startWatching() {
        watcher = DirectoryWatcher(url: rootURL) { [weak self] in
            self?.refresh()
        }
        watcher?.start()
    }

    // MARK: - Bookmarks

    /// Stores a bookmark that survives relaunch, including for folders inside
    /// iCloud Drive.
    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        return url
    }
}
