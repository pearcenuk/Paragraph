import AppKit
import XCTest
@testable import Paragraph

/// The shortcut map is the one part of Paragraph that is easy to get quietly
/// wrong: two commands can claim the same keystroke, or a command can steal a
/// key that macOS or an accessibility feature already owns, and nothing will
/// complain until a writer loses a keystroke they rely on. These tests are the
/// complaint.
final class ShortcutMapTests: XCTestCase {

    private var shortcuts: [(AppCommand, Shortcut)] {
        AppCommand.allCases.compactMap { command in
            command.shortcut.map { (command, $0) }
        }
    }

    private func signature(_ shortcut: Shortcut) -> String {
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let mask = shortcut.modifiers.intersection(relevant).rawValue
        return "\(shortcut.key.lowercased())|\(mask)"
    }

    func testNoTwoCommandsClaimTheSameKeystroke() {
        var seen: [String: AppCommand] = [:]
        for (command, shortcut) in shortcuts {
            let key = signature(shortcut)
            if let existing = seen[key] {
                XCTFail("\(command) and \(existing) both use \(shortcut.displayString)")
            }
            seen[key] = command
        }
    }

    func testNoCommandUsesVoiceOverModifiers() {
        // Control-Option is the VoiceOver key combination.
        for (command, shortcut) in shortcuts {
            XCTAssertFalse(
                shortcut.modifiers.contains(.control) && shortcut.modifiers.contains(.option),
                "\(command) uses Control-Option, which belongs to VoiceOver"
            )
        }
    }

    func testNoCommandUsesABareControlLetter() {
        // AppKit text views bind bare Control *letters* to Emacs-style movement
        // (Control-A, Control-E, Control-P, Control-K and the rest). Control with
        // a non-letter key is safe, which is why macOS itself uses Control-Tab
        // to move between tabs.
        for (command, shortcut) in shortcuts
        where shortcut.modifiers.contains(.control) && !shortcut.modifiers.contains(.command) {
            XCTAssertFalse(
                shortcut.key.count == 1 && shortcut.key.first?.isLetter == true,
                "\(command) uses a bare Control letter, which conflicts with text editing"
            )
        }
    }

    func testEstablishedSystemShortcutsKeepTheirMeaning() {
        // If any of these ever change, it is a deliberate decision, not a slip.
        let expected: [AppCommand: String] = [
            .newDocument: "\u{2318}N",
            .openDocument: "\u{2318}O",
            .save: "\u{2318}S",
            .saveAs: "\u{21E7}\u{2318}S",
            .closeTab: "\u{2318}W",
            .print: "\u{2318}P"
        ]
        for (command, rendering) in expected {
            XCTAssertEqual(command.shortcut?.displayString, rendering, "\(command)")
        }
    }

    func testQuickOpenDoesNotTakeThePrintShortcut() {
        // Command-P is Print on macOS, so Quick Open uses Shift-Command-O.
        XCTAssertEqual(AppCommand.print.shortcut?.key, "p")
        XCTAssertEqual(AppCommand.print.shortcut?.modifiers, .command)
        XCTAssertEqual(AppCommand.quickOpen.shortcut?.key, "o")
        XCTAssertEqual(AppCommand.quickOpen.shortcut?.modifiers, [.command, .shift])
    }

    func testFocusModeDoesNotTakeTheHistoricFullScreenShortcut() {
        // Control-Command-F was Enter Full Screen for many macOS releases and is
        // still muscle memory, so Paragraph stays off it.
        let focus = AppCommand.toggleFocusMode.shortcut!
        XCTAssertNotEqual(signature(focus), signature(Shortcut("f", [.command, .control])))
    }

    func testFullScreenIsLeftToTheSystem() {
        // Paragraph defines no Full Screen command; AppKit adds its own item to
        // the View menu with the key equivalent current for this macOS version.
        XCTAssertFalse(AppCommand.allCases.contains { $0.title == L10n.commandFullScreen })
    }

    func testEveryCommandHasATitleAndAnAction() {
        for command in AppCommand.allCases {
            XCTAssertFalse(command.title.isEmpty, "\(command) has no title")
            XCTAssertFalse(
                NSStringFromSelector(command.action).isEmpty,
                "\(command) has no action"
            )
        }
    }

    func testEveryRequiredCommandIsPresent() {
        // The commands the specification asks for by name.
        let required: [AppCommand] = [
            .toggleWorkspaceBrowser, .moveFocusToWorkspaceBrowser, .moveFocusToEditor,
            .quickOpen, .openInTab, .openInNewWindow, .showNextTab, .showPreviousTab,
            .closeTab, .reopenClosedTab, .toggleTypewriterMode, .toggleFocusMode,
            .toggleWordCount, .runWritingCheck, .showWritingCheckResults, .keyboardShortcuts
        ]
        for command in required {
            XCTAssertNotNil(command.shortcut, "\(command) should have a fixed shortcut")
        }
    }
}
