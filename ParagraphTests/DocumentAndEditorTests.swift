import AppKit
import XCTest
@testable import Paragraph

/// Exercises the real document, window and editor objects.
///
/// The point of these is the promise that matters most: the same file open in
/// two places is one document, not two copies racing to overwrite each other.
final class DocumentAndEditorTests: XCTestCase {

    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Inside the sandbox container, which is writable.
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ParagraphTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try super.tearDownWithError()
    }

    private func makeFile(_ name: String, _ contents: String) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func makeDocument(_ markdown: String) throws -> MarkdownDocument {
        let document = MarkdownDocument()
        try document.read(from: Data(markdown.utf8), ofType: "net.daringfireball.markdown")
        return document
    }

    // MARK: - Reading and writing

    func testReadingPopulatesTheSharedTextStorage() throws {
        let document = try makeDocument("# Title\n\nSome prose.\n")
        XCTAssertEqual(document.textStorage.string, "# Title\n\nSome prose.\n")
    }

    func testOpeningDoesNotMarkTheDocumentEdited() throws {
        // Opening a file must never be able to change it.
        let document = try makeDocument("# Title\n")
        XCTAssertFalse(document.isDocumentEdited)
    }

    func testApplyingAThemeDoesNotMarkTheDocumentEdited() throws {
        let document = try makeDocument("# Title\n")
        document.applyDisplayAttributes(theme: ThemeIdentifier.greenScreen.theme)
        XCTAssertFalse(document.isDocumentEdited,
                       "changing how text looks is not an edit to the text")
    }

    func testWritingProducesThePlainSourceOnly() throws {
        let document = try makeDocument("# Title\n\n*Emphasis* stays.\n")
        document.applyDisplayAttributes(theme: ThemeIdentifier.dark.theme)
        let data = try document.data(ofType: "net.daringfireball.markdown")
        XCTAssertEqual(String(data: data, encoding: .utf8), "# Title\n\n*Emphasis* stays.\n",
                       "display attributes must never reach the file")
    }

    func testEditingMarksTheDocumentEdited() throws {
        let document = try makeDocument("Original.\n")
        document.textStorage.replaceCharacters(in: NSRange(location: 0, length: 8), with: "Changed")
        XCTAssertTrue(document.isDocumentEdited)
    }

    func testWordCountIsPublished() throws {
        let document = try makeDocument("# Chapter One\n\nShe left the house.\n")
        // Read publishes immediately rather than on the debounce.
        let expectation = expectation(description: "word count")
        let cancellable = document.$wordCount.dropFirst().sink { count in
            if count == 6 { expectation.fulfill() }
        }
        wait(for: [expectation], timeout: 2)
        cancellable.cancel()
    }

    // MARK: - One file, one document

    func testTwoWindowsShareOneTextStorageAndOneUndoStack() throws {
        let document = try makeDocument("Shared text.\n")

        let first = DocumentWindowController(markdownDocument: document)
        document.addWindowController(first)
        let second = DocumentWindowController(markdownDocument: document)
        document.addWindowController(second)

        _ = first.editorViewController.view
        _ = second.editorViewController.view

        let firstStorage = first.editorViewController.textView.textStorage
        let secondStorage = second.editorViewController.textView.textStorage

        XCTAssertTrue(firstStorage === document.textStorage)
        XCTAssertTrue(secondStorage === document.textStorage,
                      "two views of one document must not have separate text")

        // An edit in one window is immediately present in the other.
        document.textStorage.replaceCharacters(in: NSRange(location: 0, length: 6), with: "Common")
        XCTAssertEqual(second.editorViewController.textView.string, "Common text.\n")

        // But each view keeps its own cursor.
        first.editorViewController.selectedRange = NSRange(location: 0, length: 0)
        second.editorViewController.selectedRange = NSRange(location: 5, length: 0)
        XCTAssertEqual(first.editorViewController.selectedRange.location, 0)
        XCTAssertEqual(second.editorViewController.selectedRange.location, 5)

        document.removeWindowController(first)
        document.removeWindowController(second)
    }

    func testEachViewHasItsOwnLayoutManager() throws {
        let document = try makeDocument("Text.\n")
        let first = DocumentWindowController(markdownDocument: document)
        let second = DocumentWindowController(markdownDocument: document)
        _ = first.editorViewController.view
        _ = second.editorViewController.view

        XCTAssertFalse(
            first.editorViewController.textView.layoutManager
                === second.editorViewController.textView.layoutManager,
            "shared storage requires a layout manager per view"
        )
        XCTAssertEqual(document.textStorage.layoutManagers.count, 2)
    }

    // MARK: - The writing column

    /// Lays the window out for real, so the editor gets the width the split
    /// view actually gives it rather than its minimum thickness.
    private func layOutEditor(
        _ controller: DocumentWindowController,
        windowWidth: CGFloat,
        collapseSidebar: Bool
    ) -> EditorViewController {
        let editor = controller.editorViewController
        _ = controller.window
        // Not animated: the test needs the new width to be true immediately.
        controller.setSidebarCollapsed(collapseSidebar, propagateToTabGroup: false, animated: false)
        controller.window?.setContentSize(NSSize(width: windowWidth, height: 800))
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        editor.view.layoutSubtreeIfNeeded()
        editor.textView.updateInsets()
        return editor
    }

    func testTheWritingColumnIsCentredAndCapped() throws {
        let document = try makeDocument("Some prose.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        let editor = layOutEditor(controller, windowWidth: 1600, collapseSidebar: true)

        let preferred = EditorTypography.preferredColumnWidth(for: EditorTypography.bodyFont())
        let columnWidth = editor.textView.textContainer!.size.width
        let available = editor.textView.enclosingScrollView!.contentSize.width

        XCTAssertGreaterThan(available, 1200, "the editor should have the window's width")
        XCTAssertEqual(columnWidth, preferred, accuracy: 1,
                       "the column should stop at its measure on a wide display")
        XCTAssertLessThan(columnWidth, available / 2,
                          "prose should not stretch across a large monitor")

        let inset = editor.textView.textContainerInset.width
        XCTAssertEqual(inset, (available - columnWidth) / 2, accuracy: 1,
                       "the leftover space should be split evenly, centring the column")
    }

    func testTheColumnStaysCentredWhenTheBrowserAppears() throws {
        let document = try makeDocument("Some prose.\n")
        let controller = DocumentWindowController(markdownDocument: document)

        let hidden = layOutEditor(controller, windowWidth: 1400, collapseSidebar: true)
        let widthWithoutBrowser = hidden.textView.enclosingScrollView!.contentSize.width
        let insetWithoutBrowser = hidden.textView.textContainerInset.width
        let columnWithoutBrowser = hidden.textView.textContainer!.size.width

        let shown = layOutEditor(controller, windowWidth: 1400, collapseSidebar: false)
        let widthWithBrowser = shown.textView.enclosingScrollView!.contentSize.width
        let insetWithBrowser = shown.textView.textContainerInset.width
        let columnWithBrowser = shown.textView.textContainer!.size.width

        XCTAssertLessThan(widthWithBrowser, widthWithoutBrowser,
                          "showing the browser should take width from the editor")
        // Centred relative to the *editor area*, not the window, in both states.
        XCTAssertEqual(insetWithoutBrowser,
                       (widthWithoutBrowser - columnWithoutBrowser) / 2, accuracy: 1)
        XCTAssertEqual(insetWithBrowser,
                       (widthWithBrowser - columnWithBrowser) / 2, accuracy: 1)
    }

    func testTheWritingColumnAdaptsToASmallWindow() throws {
        let document = try makeDocument("Some prose.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        let editor = layOutEditor(controller, windowWidth: 480, collapseSidebar: true)

        let available = editor.textView.enclosingScrollView!.contentSize.width
        let columnWidth = editor.textView.textContainer!.size.width

        XCTAssertGreaterThan(columnWidth, 0)
        XCTAssertLessThanOrEqual(columnWidth, available, "the column must fit the editor")
        XCTAssertGreaterThanOrEqual(editor.textView.textContainerInset.width,
                                    EditorTypography.horizontalPadding,
                                    "padding should survive in a narrow window")
    }

    func testProseStaysLeftAligned() {
        // The column is centred; the text inside it is not.
        XCTAssertEqual(EditorTypography.paragraphStyle().alignment, .left)
    }

    // MARK: - Modes

    func testTypewriterModeOpensRoomAboveAndBelow() throws {
        let document = try makeDocument(String(repeating: "A line of prose.\n", count: 40))
        let controller = DocumentWindowController(markdownDocument: document)
        let editor = controller.editorViewController
        _ = editor.view
        editor.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        editor.view.layoutSubtreeIfNeeded()

        editor.textView.typewriterModeEnabled = false
        editor.textView.updateInsets()
        let normalInset = editor.textView.textContainerInset.height

        editor.textView.typewriterModeEnabled = true
        editor.textView.updateInsets()
        let typewriterInset = editor.textView.textContainerInset.height

        XCTAssertGreaterThan(typewriterInset, normalInset,
                             "the first and last lines must be able to reach the middle")
    }

    func testFocusModeDimsOnlyOutsideTheCurrentParagraph() throws {
        let markdown = "First paragraph.\nSecond paragraph.\nThird paragraph.\n"
        let document = try makeDocument(markdown)
        let controller = DocumentWindowController(markdownDocument: document)
        let editor = controller.editorViewController
        _ = editor.view
        editor.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        editor.view.layoutSubtreeIfNeeded()
        editor.textView.updateInsets()

        // Put the cursor in the second paragraph.
        let secondParagraph = (markdown as NSString).range(of: "Second paragraph.")
        editor.textView.setSelectedRange(NSRange(location: secondParagraph.location + 2, length: 0))
        editor.textView.focusModeEnabled = true
        editor.textView.updateFocusHighlight()

        guard let layoutManager = editor.textView.layoutManager else {
            return XCTFail("expected a TextKit 1 layout manager")
        }
        let theme = Preferences.shared.currentTheme

        let insideColour = layoutManager.temporaryAttribute(
            .foregroundColor, atCharacterIndex: secondParagraph.location + 2, effectiveRange: nil
        ) as? NSColor
        let outsideColour = layoutManager.temporaryAttribute(
            .foregroundColor, atCharacterIndex: 2, effectiveRange: nil
        ) as? NSColor

        XCTAssertNil(insideColour, "the current paragraph must stay fully readable")
        XCTAssertEqual(outsideColour, theme.deEmphasisedText,
                       "surrounding text should be de-emphasised")

        // And the document itself is untouched.
        XCTAssertEqual(document.textStorage.string, markdown)
        XCTAssertFalse(document.isDocumentEdited)
    }

    func testTurningFocusModeOffRestoresEverything() throws {
        let markdown = "One.\nTwo.\nThree.\n"
        let document = try makeDocument(markdown)
        let controller = DocumentWindowController(markdownDocument: document)
        let editor = controller.editorViewController
        _ = editor.view
        editor.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        editor.view.layoutSubtreeIfNeeded()

        editor.textView.focusModeEnabled = true
        editor.textView.updateFocusHighlight()
        editor.textView.focusModeEnabled = false

        let colour = editor.textView.layoutManager?.temporaryAttribute(
            .foregroundColor, atCharacterIndex: 0, effectiveRange: nil
        )
        XCTAssertNil(colour)
    }

    // MARK: - Editor configuration

    func testEditorIsAPlainTextSourceEditorWithNativeBehaviour() throws {
        let document = try makeDocument("Text.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        let textView = controller.editorViewController.textView!
        _ = controller.editorViewController.view

        XCTAssertFalse(textView.isRichText, "Markdown source must stay plain text")
        XCTAssertTrue(textView.allowsUndo)
        XCTAssertTrue(textView.usesFindBar, "Find and Replace should be the native find bar")
        XCTAssertTrue(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertFalse(textView.isGrammarCheckingEnabled, "no grammar squiggles")
        XCTAssertFalse(textView.isAutomaticSpellingCorrectionEnabled,
                       "a novelist's invented words must not be corrected for them")
        XCTAssertFalse(textView.isAutomaticLinkDetectionEnabled,
                       "a source editor should not turn URLs into links")
        XCTAssertNotNil(textView.layoutManager, "Focus Mode needs TextKit 1 temporary attributes")
    }

    func testSpellCheckingFollowsTheSetting() throws {
        let document = try makeDocument("Text.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        _ = controller.editorViewController.view

        let original = Preferences.shared.spellCheckingEnabled
        defer { Preferences.shared.spellCheckingEnabled = original }

        Preferences.shared.spellCheckingEnabled = true
        XCTAssertTrue(controller.editorViewController.textView.isContinuousSpellCheckingEnabled)
    }

    // MARK: - Dragging files onto the editor

    func testDroppedMarkdownFilesAreRecognisedAsOpenable() throws {
        let document = try makeDocument("Text.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        let textView = controller.editorViewController.textView!
        _ = controller.editorViewController.view

        let chapter = try makeFile("Chapter03.md", "# Three\n")
        let note = try makeFile("Note.txt", "note\n")
        let image = try makeFile("Cover.png", "not text")

        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()
        pasteboard.writeObjects([chapter as NSURL, note as NSURL, image as NSURL])

        let droppable = textView.droppableFiles(in: StubDraggingInfo(pasteboard: pasteboard))
        XCTAssertEqual(Set(droppable.map(\.lastPathComponent)), ["Chapter03.md", "Note.txt"],
                       "only files Paragraph can open should be treated as a drop to open")
        XCTAssertFalse(droppable.contains(image),
                       "an image should fall through to normal text-view handling")
    }

    // MARK: - Windows and tabs

    func testDocumentWindowsCanTabTogether() throws {
        let document = try makeDocument("Text.\n")
        let first = DocumentWindowController(markdownDocument: document)
        let second = DocumentWindowController(markdownDocument: document)

        XCTAssertEqual(first.window?.tabbingIdentifier, second.window?.tabbingIdentifier,
                       "Paragraph windows must be able to become tabs of one another")
        XCTAssertEqual(first.window?.tabbingMode, .automatic)
    }

    func testWindowsDoNotUseSystemRestoration() throws {
        // Paragraph restores its own session; two mechanisms would fight.
        let document = try makeDocument("Text.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        XCTAssertFalse(controller.window?.isRestorable ?? true)
    }

    func testTheWindowShowsTheDocumentNameNotItsPath() throws {
        let url = try makeFile("Chapter02.md", "# Chapter Two\n")
        let document = try makeDocument("# Chapter Two\n")
        document.fileURL = url
        let controller = DocumentWindowController(markdownDocument: document)
        let title = controller.windowTitle(forDocumentDisplayName: document.displayName)
        XCTAssertEqual(title, document.displayName)
        XCTAssertFalse(title.contains("/"), "tabs and titles must not show full paths")
    }

    func testTheWindowHasASidebarAndAVisibleControlForIt() throws {
        let document = try makeDocument("Text.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        _ = controller.window

        let split = controller.window?.contentViewController as? NSSplitViewController
        XCTAssertEqual(split?.splitViewItems.count, 2)
        XCTAssertTrue(split?.splitViewItems.first?.canCollapse ?? false)

        // The browser must be hideable by clicking as well as by menu command.
        let toolbar = controller.window?.toolbar
        XCTAssertNotNil(toolbar, "there should be a control to click")
        let identifiers = toolbar?.items.map(\.itemIdentifier.rawValue) ?? []
        XCTAssertTrue(identifiers.contains { $0.contains("ToggleSidebar") })
    }

    func testTogglingTheBrowserWorks() throws {
        let document = try makeDocument("Text.\n")
        let controller = DocumentWindowController(markdownDocument: document)
        _ = controller.window

        let before = controller.isSidebarCollapsed
        controller.setSidebarCollapsed(!before, propagateToTabGroup: false)
        XCTAssertNotEqual(controller.isSidebarCollapsed, before)
    }
}


/// Minimal stand-in so the drop filtering can be tested without a real drag.
private final class StubDraggingInfo: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    init(pasteboard: NSPasteboard) { self.draggingPasteboard = pasteboard }

    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingSequenceNumber: Int { 0 }
    var draggingSource: Any? { nil }
    var draggingFormation: NSDraggingFormation {
        get { .default } set { _ = newValue }
    }
    var animatesToDestination: Bool {
        get { false } set { _ = newValue }
    }
    var numberOfValidItemsForDrop: Int {
        get { 0 } set { _ = newValue }
    }
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions,
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any],
        using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
    func resetSpringLoading() {}
}
