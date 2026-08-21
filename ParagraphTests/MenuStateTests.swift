import AppKit
import XCTest
@testable import Paragraph

/// Menu ticks were silently missing because `validateMenuItem(_:)` existed but
/// was never exposed to Objective-C, so AppKit never called it. These tests
/// pin down both halves: the conformance, and the state it sets.
final class MenuStateTests: XCTestCase {

    private let delegate = AppDelegate()

    func testValidationIsVisibleToAppKit() {
        // The compile-time conformance is not the point; the runtime exposure
        // is. Without `NSMenuItemValidation`, Swift never marks the method
        // @objc, `respondsToSelector:` returns false, and AppKit skips it.
        XCTAssertTrue(delegate.responds(to: #selector(NSMenuItemValidation.validateMenuItem(_:))),
                      "validateMenuItem(_:) is not exposed to Objective-C")
    }

    func testModeCommandsShowTheirCheckedState() {
        for (command, keyPath) in [
            (AppCommand.toggleTypewriterMode, \Preferences.typewriterMode),
            (AppCommand.toggleFocusMode, \Preferences.focusMode),
            (AppCommand.toggleWordCount, \Preferences.wordCountVisible)
        ] as [(AppCommand, ReferenceWritableKeyPath<Preferences, Bool>)] {
            let original = Preferences.shared[keyPath: keyPath]
            defer { Preferences.shared[keyPath: keyPath] = original }

            let item = command.makeMenuItem()

            Preferences.shared[keyPath: keyPath] = true
            _ = delegate.validateMenuItem(item)
            XCTAssertEqual(item.state, .on, "\(command) should be ticked when on")

            Preferences.shared[keyPath: keyPath] = false
            _ = delegate.validateMenuItem(item)
            XCTAssertEqual(item.state, .off, "\(command) should be unticked when off")
        }
    }

    func testOnlyTheActiveThemeIsTicked() {
        let original = Preferences.shared.theme
        defer { Preferences.shared.theme = original }

        Preferences.shared.theme = .greenScreen
        let items = [AppCommand.themeLight, .themeDark, .themeGreenScreen].map { command -> (AppCommand, NSMenuItem) in
            let item = command.makeMenuItem()
            _ = delegate.validateMenuItem(item)
            return (command, item)
        }
        let ticked = items.filter { $0.1.state == .on }.map(\.0)
        XCTAssertEqual(ticked, [.themeGreenScreen], "exactly the active theme should be ticked")
    }
}
