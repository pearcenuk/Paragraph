import AppKit
import Combine
import ParagraphKit

extension Notification.Name {
    static let paragraphDocumentWillReload = Notification.Name("ParagraphDocumentWillReload")
    static let paragraphDocumentDidReload = Notification.Name("ParagraphDocumentDidReload")
    static let paragraphDocumentConflictChanged = Notification.Name("ParagraphDocumentConflictChanged")
}

/// One open Markdown or plain-text file.
///
/// `NSDocument` is doing a great deal of work here that would otherwise have to
/// be written and got wrong: coordinated reads and writes, safe-save through a
/// temporary file, the Versions browser, Rename and Move To, the edited dot in
/// the title bar, and — most importantly — the guarantee from
/// `NSDocumentController` that one file on disk is one document in memory, no
/// matter how many tabs or windows are showing it.
///
/// The text itself lives in a single ``NSTextStorage``. Every view of this
/// document attaches its own layout manager to that one storage, which is what
/// makes two windows onto the same file share edits and an undo stack instead of
/// becoming two conflicting copies.
final class MarkdownDocument: NSDocument, ObservableObject {

    /// Shared by every editor showing this document.
    let textStorage = NSTextStorage()

    /// Everything needed to write the file back exactly as it was read.
    private(set) var fileContents = TextFileContents.empty

    /// Set when the file changed on disk while the writer had unsaved edits.
    @Published private(set) var hasExternalConflict = false

    /// The only continuously visible statistic in the application.
    @Published private(set) var wordCount = 0

    private var isLoading = false
    private var isApplyingDisplayAttributes = false
    private var wordCountWork: DispatchWorkItem?
    private var themeObserver: AnyCancellable?

    // MARK: - Lifecycle

    override init() {
        super.init()
        hasUndoManager = true
        textStorage.delegate = self
        themeObserver = Preferences.shared.$theme
            .receive(on: RunLoop.main)
            .sink { [weak self] identifier in
                self?.applyDisplayAttributes(theme: identifier.theme)
            }
    }

    /// Autosaving in place is right for a writing application: a writer should
    /// never lose an afternoon because they forgot to press Command-S. It is
    /// also what gives Paragraph the standard Revert, Duplicate and Rename
    /// behaviour without implementing any of it.
    override class var autosavesInPlace: Bool { true }

    override class var preservesVersions: Bool { true }

    /// A new document is autosaved as a draft, so work done before the writer
    /// has chosen a filename is not lost either.
    override class var autosavesDrafts: Bool { true }

    // MARK: - Reading and writing

    override func read(from data: Data, ofType typeName: String) throws {
        let contents = try TextFileContents.read(from: data)
        fileContents = contents

        isLoading = true
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length),
                                      with: contents.text)
        textStorage.endEditing()
        isLoading = false

        applyDisplayAttributes(theme: Preferences.shared.currentTheme)
        recalculateWordCount(immediately: true)
        setConflict(false)
    }

    override func data(ofType typeName: String) throws -> Data {
        // Only the plain string is ever written. Display attributes such as the
        // theme's text colour exist for the screen and never reach the file.
        try fileContents.data(for: textStorage.string)
    }

    override func makeWindowControllers() {
        guard windowControllers.isEmpty else { return }
        addWindowController(DocumentWindowController(markdownDocument: self))
    }

    // MARK: - External changes

    /// Called by the file coordination machinery when something else touches the
    /// file — another editor, or iCloud Drive bringing down a newer version.
    override func presentedItemDidChange() {
        guard let url = fileURL else { return }
        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        guard let modified, modified != fileModificationDate else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleExternalChange()
        }
        super.presentedItemDidChange()
    }

    private func handleExternalChange() {
        guard let url = fileURL, let type = fileType else { return }

        guard !isDocumentEdited else {
            // Never overwrite silently, and never throw away the writer's work.
            // The editor shows a banner offering both directions.
            setConflict(true)
            return
        }

        NotificationCenter.default.post(name: .paragraphDocumentWillReload, object: self)
        do {
            try revert(toContentsOf: url, ofType: type)
            NotificationCenter.default.post(name: .paragraphDocumentDidReload, object: self)
        } catch {
            // A file that has become unreadable is reported, not repaired.
            setConflict(true)
        }
    }

    /// Discards local edits and takes the version on disk.
    func reloadFromDisk() {
        guard let url = fileURL, let type = fileType else { return }
        NotificationCenter.default.post(name: .paragraphDocumentWillReload, object: self)
        try? revert(toContentsOf: url, ofType: type)
        updateChangeCount(.changeCleared)
        setConflict(false)
        NotificationCenter.default.post(name: .paragraphDocumentDidReload, object: self)
    }

    /// Keeps the in-memory version; the next save will replace what is on disk.
    func keepCurrentVersion() {
        setConflict(false)
    }

    private func setConflict(_ value: Bool) {
        guard hasExternalConflict != value else { return }
        hasExternalConflict = value
        NotificationCenter.default.post(name: .paragraphDocumentConflictChanged, object: self)
    }

    // MARK: - Display attributes

    /// Applies the font, measure and theme colours to the whole storage.
    ///
    /// These are display attributes only. They are re-applied when the theme
    /// changes and are deliberately excluded from the document's change count,
    /// because changing how text looks is not an edit to the text.
    func applyDisplayAttributes(theme: Theme) {
        guard textStorage.length > 0 || !isLoading else { return }
        isApplyingDisplayAttributes = true
        defer { isApplyingDisplayAttributes = false }

        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.setAttributes(Self.attributes(for: theme), range: range)
        textStorage.endEditing()
    }

    static func attributes(for theme: Theme) -> [NSAttributedString.Key: Any] {
        [
            .font: EditorTypography.bodyFont(),
            .foregroundColor: theme.bodyText,
            .paragraphStyle: EditorTypography.paragraphStyle()
        ]
    }

    // MARK: - Word count

    /// Recomputed on a short debounce rather than on every keystroke, and off
    /// the main thread, so a long chapter does not make typing feel heavy.
    private func recalculateWordCount(immediately: Bool = false) {
        wordCountWork?.cancel()
        let snapshot = textStorage.string

        let work = DispatchWorkItem { [weak self] in
            let count = WordCounter.count(markdown: snapshot)
            DispatchQueue.main.async { self?.wordCount = count }
        }
        wordCountWork = work

        if immediately {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        } else {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    // MARK: - Printing

    override func printOperation(withSettings settings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
        printView.textStorage?.setAttributedString(textStorage)
        let operation = NSPrintOperation(view: printView, printInfo: printInfo)
        operation.printInfo.dictionary().addEntries(from: settings)
        return operation
    }
}

// MARK: - NSTextStorageDelegate

extension MarkdownDocument: NSTextStorageDelegate {
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        guard !isLoading, !isApplyingDisplayAttributes else { return }

        updateChangeCount(.changeDone)
        recalculateWordCount()
    }
}
