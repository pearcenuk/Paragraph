import AppKit

/// Builds the menu bar in code from ``AppCommand``.
///
/// Menus are assembled here rather than in a nib so that every title is a
/// localised string and every application shortcut comes from one table. Where
/// macOS already has a command — Undo, Find, Spelling, the tab commands — the
/// standard selector is used and its behaviour left alone.
enum MenuBuilder {

    static func install() {
        let mainMenu = NSMenu()
        mainMenu.addItem(applicationMenuItem())
        mainMenu.addItem(menuItem(title: L10n.menuFile, menu: fileMenu()))
        mainMenu.addItem(menuItem(title: L10n.menuEdit, menu: editMenu()))
        mainMenu.addItem(menuItem(title: L10n.menuView, menu: viewMenu()))
        mainMenu.addItem(menuItem(title: L10n.menuNavigate, menu: navigateMenu()))
        mainMenu.addItem(menuItem(title: L10n.menuWriting, menu: writingMenu()))

        let windowMenu = self.windowMenu()
        mainMenu.addItem(menuItem(title: L10n.menuWindow, menu: windowMenu))

        let helpMenu = self.helpMenu()
        mainMenu.addItem(menuItem(title: L10n.menuHelp, menu: helpMenu))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }

    // MARK: - Helpers

    private static func menuItem(title: String, menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menu.title = title
        item.submenu = menu
        return item
    }

    private static func add(_ command: AppCommand, to menu: NSMenu) {
        menu.addItem(command.makeMenuItem())
    }

    private static func add(
        _ title: String,
        _ selector: Selector?,
        _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command,
        tag: Int? = nil,
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        if let tag { item.tag = tag }
        menu.addItem(item)
    }

    // MARK: - Application menu

    private static func applicationMenuItem() -> NSMenuItem {
        let name = L10n.applicationName
        let menu = NSMenu()

        add(L10n.about(name), #selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: menu)
        menu.addItem(.separator())
        add(L10n.settings, #selector(AppDelegate.showSettings(_:)), ",", to: menu)
        menu.addItem(.separator())

        let services = NSMenu(title: L10n.services)
        let servicesItem = NSMenuItem(title: L10n.services, action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        menu.addItem(servicesItem)
        NSApp.servicesMenu = services

        menu.addItem(.separator())
        add(L10n.hide(name), #selector(NSApplication.hide(_:)), "h", to: menu)
        add(L10n.hideOthers, #selector(NSApplication.hideOtherApplications(_:)), "h",
            [.command, .option], to: menu)
        add(L10n.showAll, #selector(NSApplication.unhideAllApplications(_:)), to: menu)
        menu.addItem(.separator())
        add(L10n.quit(name), #selector(NSApplication.terminate(_:)), "q", to: menu)

        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    // MARK: - File

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu()
        add(.newDocument, to: menu)
        add(.openDocument, to: menu)

        // Built from `NSDocumentController.recentDocumentURLs` through a menu
        // delegate, rather than relying on the nib-only magic menu name.
        let recent = NSMenu(title: L10n.commandOpenRecent)
        recent.delegate = RecentDocumentsMenuDelegate.shared
        menu.addItem(submenu(recent, titled: L10n.commandOpenRecent))

        add(.openWorkspaceFolder, to: menu)
        menu.addItem(.separator())
        add(.closeTab, to: menu)
        add(.save, to: menu)
        add(.saveAs, to: menu)
        add(.revert, to: menu)
        menu.addItem(.separator())
        add(.revealInFinder, to: menu)
        menu.addItem(.separator())
        add(.print, to: menu)
        return menu
    }

    // MARK: - Edit

    private static func editMenu() -> NSMenu {
        let menu = NSMenu()
        add(L10n.commandUndo, Selector(("undo:")), "z", to: menu)
        add(L10n.commandRedo, Selector(("redo:")), "z", [.command, .shift], to: menu)
        menu.addItem(.separator())
        add(L10n.commandCut, #selector(NSText.cut(_:)), "x", to: menu)
        add(L10n.commandCopy, #selector(NSText.copy(_:)), "c", to: menu)
        add(L10n.commandPaste, #selector(NSText.paste(_:)), "v", to: menu)
        add(L10n.commandDelete, #selector(NSText.delete(_:)), to: menu)
        add(L10n.commandSelectAll, #selector(NSText.selectAll(_:)), "a", to: menu)
        menu.addItem(.separator())

        // The native find bar, with its standard actions and keys.
        let find = NSMenu(title: L10n.commandFind)
        add(L10n.commandFindEllipsis, #selector(NSTextView.performTextFinderAction(_:)), "f",
            tag: NSTextFinder.Action.showFindInterface.rawValue, to: find)
        add(L10n.commandFindReplace, #selector(NSTextView.performTextFinderAction(_:)), "f",
            [.command, .option],
            tag: NSTextFinder.Action.showReplaceInterface.rawValue, to: find)
        add(L10n.commandFindNext, #selector(NSTextView.performTextFinderAction(_:)), "g",
            tag: NSTextFinder.Action.nextMatch.rawValue, to: find)
        add(L10n.commandFindPrevious, #selector(NSTextView.performTextFinderAction(_:)), "g",
            [.command, .shift],
            tag: NSTextFinder.Action.previousMatch.rawValue, to: find)
        add(L10n.commandUseSelectionForFind, #selector(NSTextView.performTextFinderAction(_:)), "e",
            tag: NSTextFinder.Action.setSearchString.rawValue, to: find)
        menu.addItem(submenu(find, titled: L10n.commandFind))

        // Spelling stays exactly where a Mac user expects to find it.
        let spelling = NSMenu(title: L10n.commandSpelling)
        add(L10n.commandShowSpelling, #selector(NSText.showGuessPanel(_:)), ":", to: spelling)
        add(L10n.commandCheckDocumentNow, #selector(NSText.checkSpelling(_:)), ";", to: spelling)
        spelling.addItem(.separator())
        add(.toggleSpellChecking, to: spelling)
        menu.addItem(submenu(spelling, titled: L10n.commandSpelling))

        let substitutions = NSMenu(title: L10n.commandSubstitutions)
        add(L10n.commandSmartQuotes,
            #selector(NSTextView.toggleAutomaticQuoteSubstitution(_:)), to: substitutions)
        add(L10n.commandSmartDashes,
            #selector(NSTextView.toggleAutomaticDashSubstitution(_:)), to: substitutions)
        menu.addItem(submenu(substitutions, titled: L10n.commandSubstitutions))

        return menu
    }

    private static func submenu(_ menu: NSMenu, titled title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    // MARK: - View

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu()
        add(.toggleWorkspaceBrowser, to: menu)
        add(.toggleWordCount, to: menu)
        menu.addItem(.separator())

        let themes = NSMenu(title: L10n.commandTheme)
        add(.themeLight, to: themes)
        add(.themeDark, to: themes)
        add(.themeGreenScreen, to: themes)
        menu.addItem(submenu(themes, titled: L10n.commandTheme))
        menu.addItem(.separator())
        add(.increaseFontSize, to: menu)
        add(.decreaseFontSize, to: menu)
        add(.actualFontSize, to: menu)
        // AppKit appends its own Enter Full Screen item to this menu, using the
        // key equivalent current for this version of macOS. Adding one here
        // would duplicate it.
        return menu
    }

    // MARK: - Navigate

    private static func navigateMenu() -> NSMenu {
        let menu = NSMenu()
        add(.quickOpen, to: menu)
        menu.addItem(.separator())
        add(.moveFocusToWorkspaceBrowser, to: menu)
        add(.moveFocusToEditor, to: menu)
        menu.addItem(.separator())
        add(.openInTab, to: menu)
        add(.openInNewWindow, to: menu)
        menu.addItem(.separator())
        add(.showNextTab, to: menu)
        add(.showPreviousTab, to: menu)
        add(.reopenClosedTab, to: menu)
        return menu
    }

    // MARK: - Writing

    private static func writingMenu() -> NSMenu {
        let menu = NSMenu()
        add(.toggleTypewriterMode, to: menu)
        add(.toggleFocusMode, to: menu)
        menu.addItem(.separator())
        add(.runWritingCheck, to: menu)
        return menu
    }

    // MARK: - Window and Help

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu()
        add(L10n.commandMinimise, #selector(NSWindow.performMiniaturize(_:)), "m", to: menu)
        add(L10n.commandZoom, #selector(NSWindow.performZoom(_:)), to: menu)
        menu.addItem(.separator())
        // AppKit adds the tab commands — Show All Tabs, Move Tab to New Window,
        // Merge All Windows — to this menu itself.
        add(L10n.commandBringAllToFront, #selector(NSApplication.arrangeInFront(_:)), to: menu)
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu()
        add(.keyboardShortcuts, to: menu)
        return menu
    }
}
