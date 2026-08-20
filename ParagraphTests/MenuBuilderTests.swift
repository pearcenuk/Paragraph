import AppKit
import XCTest
@testable import Paragraph

/// The menus are the discoverable half of the interface: every command has to be
/// reachable with a mouse, and every shortcut has to be shown next to the command
/// it belongs to.
final class MenuBuilderTests: XCTestCase {

    private var mainMenu: NSMenu!

    override func setUp() {
        super.setUp()
        MenuBuilder.install()
        mainMenu = NSApp.mainMenu
    }

    private func allItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item -> [NSMenuItem] in
            [item] + (item.submenu.map(allItems(in:)) ?? [])
        }
    }

    func testMenuBarHasTheExpectedMenus() {
        let titles = mainMenu.items.compactMap { $0.submenu?.title }
        for expected in [L10n.menuFile, L10n.menuEdit, L10n.menuView,
                         L10n.menuNavigate, L10n.menuWriting, L10n.menuWindow, L10n.menuHelp] {
            XCTAssertTrue(titles.contains(expected), "missing \(expected) menu")
        }
    }

    func testNoTwoMenuItemsShareAKeyEquivalent() {
        var seen: [String: String] = [:]
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

        for item in allItems(in: mainMenu) where !item.keyEquivalent.isEmpty {
            let mask = item.keyEquivalentModifierMask.intersection(relevant).rawValue
            let signature = "\(item.keyEquivalent.lowercased())|\(mask)"
            if let existing = seen[signature] {
                XCTFail("“\(item.title)” and “\(existing)” share a key equivalent")
            }
            seen[signature] = item.title
        }
    }

    func testEveryCommandWithAShortcutShowsItInAMenu() {
        let items = allItems(in: mainMenu)

        for command in AppCommand.allCases {
            guard let shortcut = command.shortcut else { continue }
            let match = items.first { $0.title == command.title }
            XCTAssertNotNil(match, "“\(command.title)” does not appear in any menu")
            XCTAssertEqual(match?.keyEquivalent, shortcut.key, "\(command)")
            XCTAssertEqual(
                match?.keyEquivalentModifierMask.intersection([.command, .option, .control, .shift]),
                shortcut.modifiers,
                "\(command)"
            )
        }
    }

    func testEveryCommandIsReachableWithoutAKeyboard() {
        // Shortcuts are accelerators; the menu item is the real affordance.
        let titles = Set(allItems(in: mainMenu).map(\.title))
        for command in AppCommand.allCases {
            XCTAssertTrue(titles.contains(command.title), "“\(command.title)” has no menu item")
        }
    }

    func testEveryMenuItemHasAnAction() {
        for item in allItems(in: mainMenu) where !item.isSeparatorItem && item.submenu == nil {
            XCTAssertNotNil(item.action, "“\(item.title)” does nothing")
        }
    }

    func testSpellCheckingIsWhereMacUsersExpectIt() {
        let edit = mainMenu.items.first { $0.submenu?.title == L10n.menuEdit }?.submenu
        let spelling = edit?.items.first { $0.submenu?.title == L10n.commandSpelling }?.submenu
        XCTAssertNotNil(spelling, "Spelling and Grammar submenu is missing from Edit")

        let actions = spelling?.items.compactMap(\.action) ?? []
        XCTAssertTrue(actions.contains(#selector(NSTextView.toggleContinuousSpellChecking(_:))),
                      "no command to turn spell checking on or off")
    }
}
