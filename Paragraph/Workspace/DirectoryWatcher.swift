import Foundation

/// Watches a folder and everything below it for changes made by anything at all
/// — Finder, another editor, a script, or iCloud Drive bringing a change down.
///
/// `FSEvents` is used rather than file coordination because it reports changes
/// whether or not whatever made them cooperated with the coordination system.
final class DirectoryWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "me.npearce.Paragraph.directory-watcher")

    /// Changes arrive in bursts while a folder syncs; coalesce them.
    private let latency: CFTimeInterval = 0.5

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit { stop() }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<DirectoryWatcher>.fromOpaque(info)
                .takeUnretainedValue()
                .onChange()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
