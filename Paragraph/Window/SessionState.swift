import AppKit

/// What Paragraph remembers about the way the writer left it.
///
/// Restoration is a convenience and never a risk: nothing here can cause a file
/// to be written, and anything that cannot be found is reported rather than
/// recreated.
struct SessionState: Codable {
    var version = 1
    var windows: [WindowSession] = []
}

struct WindowSession: Codable {
    /// `NSStringFromRect`, so the model stays a plain value type.
    var frame: String
    var sidebarCollapsed: Bool
    var activeTabIndex: Int
    var tabs: [TabSession]
}

struct TabSession: Codable {
    /// A security-scoped bookmark, which is what allows a sandboxed Paragraph to
    /// reopen a file — including one in iCloud Drive — without asking again.
    var bookmark: Data?
    /// Kept alongside the bookmark purely so a missing file can be named.
    var path: String
    var selectionLocation: Int
    var scrollFraction: Double
}

/// Reads and writes the session file.
enum SessionStore {

    private static var fileURL: URL? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let directory = support?.appendingPathComponent("Paragraph", isDirectory: true) else {
            return nil
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Session.json")
    }

    static func load() -> SessionState? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SessionState.self, from: data)
    }

    static func save(_ state: SessionState) {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolve(_ bookmark: Data) -> URL? {
        var stale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }
}
