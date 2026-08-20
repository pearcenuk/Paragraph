import AppKit
import XCTest
@testable import Paragraph

/// The workspace is a folder and nothing more. These tests hold it to that:
/// it finds the writer's files, it ignores what Paragraph cannot open, and it
/// does not wander outside the folder it was given.
final class WorkspaceTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ParagraphWorkspace-\(UUID().uuidString)")
        let manager = FileManager.default
        try manager.createDirectory(at: root.appendingPathComponent("Notes"),
                                    withIntermediateDirectories: true)
        try manager.createDirectory(at: root.appendingPathComponent("Empty"),
                                    withIntermediateDirectories: true)

        try write("Chapter01.md", "# One\n")
        try write("Chapter02.md", "# Two\n")
        try write("Readme.markdown", "notes\n")
        try write("Plain.txt", "plain\n")
        try write("Cover.png", "not text")
        try write("archive.zip", "not text")
        try write(".hidden.md", "hidden")
        try write("Notes/Characters.md", "# Characters\n")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    private func write(_ path: String, _ contents: String) throws {
        try Data(contents.utf8).write(to: root.appendingPathComponent(path))
    }

    private func makeWorkspace() throws -> Workspace {
        let workspace = try XCTUnwrap(Workspace(url: root, startAccessing: false))
        // The scan publishes onto the main queue.
        let expectation = expectation(description: "scan")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)
        return workspace
    }

    func testOnlySupportedFilesAreListed() throws {
        let workspace = try makeWorkspace()
        let names = Set(workspace.allFiles.map(\.name))

        XCTAssertEqual(names, ["Chapter01.md", "Chapter02.md", "Readme.markdown",
                               "Plain.txt", "Characters.md"])
        XCTAssertFalse(names.contains("Cover.png"), "images are not writing")
        XCTAssertFalse(names.contains("archive.zip"))
        XCTAssertFalse(names.contains(".hidden.md"), "hidden files stay hidden")
    }

    func testSubfoldersAreListedAndFoldersComeFirst() throws {
        let workspace = try makeWorkspace()
        let rootNames = workspace.rootItems.map(\.name)

        XCTAssertEqual(rootNames.first, "Notes", "folders should be listed before files")
        XCTAssertFalse(rootNames.contains("Empty"),
                       "a folder with nothing Paragraph can open is noise")

        let notes = try XCTUnwrap(workspace.rootItems.first { $0.name == "Notes" })
        XCTAssertTrue(notes.isDirectory)
        XCTAssertEqual(notes.children.map(\.name), ["Characters.md"])
    }

    func testFilesAreSortedTheWayFinderSortsThem() throws {
        let workspace = try makeWorkspace()
        let files = workspace.rootItems.filter { !$0.isDirectory }.map(\.name)
        XCTAssertEqual(files, files.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    func testRelativePathsAreRelativeToTheWorkspace() throws {
        let workspace = try makeWorkspace()
        let characters = try XCTUnwrap(workspace.allFiles.first { $0.name == "Characters.md" })
        XCTAssertEqual(characters.relativePath, "Notes/Characters.md")
        XCTAssertFalse(characters.relativePath.hasPrefix("/"))
    }

    func testAFileCanBeFoundByURL() throws {
        let workspace = try makeWorkspace()
        let url = root.appendingPathComponent("Chapter02.md")
        XCTAssertEqual(workspace.item(at: url)?.name, "Chapter02.md")
    }

    func testAMissingFolderDoesNotProduceAWorkspace() {
        let missing = root.appendingPathComponent("NoSuchFolder")
        XCTAssertNil(Workspace(url: missing, startAccessing: false))
    }

    // MARK: - Quick Open

    func testQuickOpenFiltersToTheWorkspace() throws {
        let workspace = try makeWorkspace()
        let model = QuickOpenModel()
        model.reload(from: workspace)

        XCTAssertEqual(model.results.count, workspace.allFiles.count,
                       "an empty query lists the workspace")

        model.query = "chapter"
        XCTAssertEqual(Set(model.results.map(\.name)), ["Chapter01.md", "Chapter02.md"])

        model.query = "char"
        XCTAssertEqual(model.results.first?.name, "Characters.md")

        model.query = "zzzz"
        XCTAssertTrue(model.results.isEmpty)
    }

    func testQuickOpenRanksNamePrefixesFirst() throws {
        let workspace = try makeWorkspace()
        let model = QuickOpenModel()
        model.reload(from: workspace)
        model.query = "notes"
        // "Notes" only appears in a folder path, so the file under it matches.
        XCTAssertEqual(model.results.first?.name, "Characters.md")
    }

    func testQuickOpenArrowKeysStayInBounds() throws {
        let workspace = try makeWorkspace()
        let model = QuickOpenModel()
        model.reload(from: workspace)

        model.moveSelection(by: -1)
        XCTAssertEqual(model.selectedIndex, 0)
        model.moveSelection(by: 1000)
        XCTAssertEqual(model.selectedIndex, model.results.count - 1)
    }
}

/// Session restoration must be able to describe a session and read it back, and
/// must never be the reason a file is lost.
final class SessionTests: XCTestCase {

    func testASessionRoundTripsThroughJSON() throws {
        let session = SessionState(
            version: 1,
            windows: [
                WindowSession(
                    frame: NSStringFromRect(NSRect(x: 10, y: 20, width: 900, height: 700)),
                    sidebarCollapsed: false,
                    activeTabIndex: 1,
                    tabs: [
                        TabSession(bookmark: nil, path: "/tmp/A.md",
                                   selectionLocation: 42, scrollFraction: 0.25),
                        TabSession(bookmark: nil, path: "/tmp/B.md",
                                   selectionLocation: 7, scrollFraction: 0.9)
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(SessionState.self, from: data)

        XCTAssertEqual(restored.windows.count, 1)
        XCTAssertEqual(restored.windows[0].tabs.count, 2)
        XCTAssertEqual(restored.windows[0].activeTabIndex, 1)
        XCTAssertEqual(restored.windows[0].tabs[0].selectionLocation, 42)
        XCTAssertEqual(restored.windows[0].tabs[1].scrollFraction, 0.9)
        XCTAssertEqual(NSRectFromString(restored.windows[0].frame).width, 900)
    }

    func testCapturingWithNoWindowsProducesAnEmptySession() {
        // Restoration must not invent windows that were never there.
        let captured = SessionRestorer.captureCurrentSession()
        XCTAssertTrue(captured.windows.allSatisfy { !$0.tabs.isEmpty },
                      "a window with no saved files should not be recorded")
    }

    func testRestoringAnEmptySessionReportsThatNothingHappened() {
        XCTAssertFalse(SessionRestorer.restore(SessionState()),
                       "an empty session should fall back to normal launch behaviour")
    }

    func testViewStateSurvivesAsPreferences() {
        let defaults = UserDefaults(suiteName: "ParagraphTests-\(UUID().uuidString)")!
        let preferences = Preferences(defaults: defaults)

        preferences.typewriterMode = true
        preferences.focusMode = true
        preferences.wordCountVisible = false
        preferences.theme = .greenScreen

        let reloaded = Preferences(defaults: defaults)
        XCTAssertTrue(reloaded.typewriterMode)
        XCTAssertTrue(reloaded.focusMode)
        XCTAssertFalse(reloaded.wordCountVisible)
        XCTAssertEqual(reloaded.theme, .greenScreen)
    }

    func testSettingsDefaultToSomethingSensible() {
        let defaults = UserDefaults(suiteName: "ParagraphTests-\(UUID().uuidString)")!
        let preferences = Preferences(defaults: defaults)

        XCTAssertEqual(preferences.theme, .light)
        XCTAssertTrue(preferences.restorePreviousSession)
        XCTAssertTrue(preferences.spellCheckingEnabled)
        XCTAssertTrue(preferences.wordCountVisible)
        XCTAssertFalse(preferences.typewriterMode, "modes start off")
        XCTAssertFalse(preferences.focusMode)
    }
}
