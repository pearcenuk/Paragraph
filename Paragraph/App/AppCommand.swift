import AppKit

/// Where a command appears in the Keyboard Shortcuts reference.
enum ShortcutCategory: String, CaseIterable {
    case file
    case edit
    case view
    case navigate
    case writing
    case window
    case help

    var localizedTitle: String {
        switch self {
        case .file: return L10n.menuFile
        case .edit: return L10n.menuEdit
        case .view: return L10n.menuView
        case .navigate: return L10n.menuNavigate
        case .writing: return L10n.menuWriting
        case .window: return L10n.menuWindow
        case .help: return L10n.menuHelp
        }
    }
}

/// A keystroke, described once and used by both the menus and the Keyboard
/// Shortcuts window so the two can never disagree.
struct Shortcut {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    init(_ key: String, _ modifiers: NSEvent.ModifierFlags = .command) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Rendered the way macOS renders it, for the reference window.
    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "\u{2303}" }
        if modifiers.contains(.option) { result += "\u{2325}" }
        if modifiers.contains(.shift) { result += "\u{21E7}" }
        if modifiers.contains(.command) { result += "\u{2318}" }

        switch key {
        case "\r": result += "\u{21A9}"
        case "\t": result += "\u{21E5}"
        case "\u{1B}": result += "\u{238B}"
        case "\u{8}": result += "\u{232B}"
        default: result += key.uppercased()
        }
        return result
    }
}

/// Every command Paragraph adds to the ones macOS already provides.
///
/// Application-specific key equivalents are defined here and nowhere else. The
/// menu bar and the Keyboard Shortcuts window both read this table, so a
/// shortcut cannot drift out of step with the menu item that carries it.
///
/// ## Conflicts considered
///
/// - `⌘P` is left to Print. Quick Open takes `⇧⌘O`, matching Xcode's
///   "Open Quickly" and reading as a sibling of `⌘O` Open.
/// - Full Screen is not defined here at all. AppKit adds its own Enter Full
///   Screen item to the View menu with whatever key equivalent the running
///   version of macOS uses, which has changed over time. Defining a second one
///   would duplicate the item and pin it to an outdated key. Focus Mode still
///   avoids `⌃⌘F` and takes `⌃⌘P` — the focus unit is the paragraph, in an
///   application called Paragraph.
/// - `⌥⌘S` for the browser follows Finder's Hide Sidebar.
/// - No command uses `⌃⌥`, which belongs to VoiceOver.
/// - No command uses a bare `⌃` key, which AppKit text views bind to Emacs-style
///   cursor movement (`⌃A`, `⌃E`, `⌃P`, `⌃K` and the rest).
/// - `⌘0` belongs to Actual Size in every Mac application that scales text, so
///   the panes take `⌘1` and `⌘2` rather than `⌘1` and `⌘0`.
enum AppCommand: String, CaseIterable {
    // File
    case newDocument
    case openDocument
    case openWorkspaceFolder
    case closeTab
    case save
    case saveAs
    case revert
    case revealInFinder
    case print

    // View
    case toggleWorkspaceBrowser
    case toggleWordCount
    case themeLight
    case themeDark
    case themeGreenScreen
    case increaseFontSize
    case decreaseFontSize
    case actualFontSize

    // Navigate
    case quickOpen
    case moveFocusToWorkspaceBrowser
    case moveFocusToEditor
    case openInTab
    case openInNewWindow
    case showNextTab
    case showPreviousTab
    case reopenClosedTab

    // Writing
    case toggleTypewriterMode
    case toggleFocusMode
    case toggleSpellChecking
    case runWritingCheck

    // Help
    case keyboardShortcuts

    var title: String {
        switch self {
        case .newDocument: return L10n.commandNew
        case .openDocument: return L10n.commandOpen
        case .openWorkspaceFolder: return L10n.commandOpenWorkspace
        case .closeTab: return L10n.commandClose
        case .save: return L10n.commandSave
        case .saveAs: return L10n.commandSaveAs
        case .revert: return L10n.commandRevert
        case .revealInFinder: return L10n.commandRevealInFinder
        case .print: return L10n.commandPrint

        case .toggleWorkspaceBrowser: return L10n.commandToggleWorkspaceBrowser
        case .toggleWordCount: return L10n.commandToggleWordCount
        case .themeLight: return L10n.themeLight
        case .themeDark: return L10n.themeDark
        case .themeGreenScreen: return L10n.themeGreenScreen
        case .increaseFontSize: return L10n.commandBigger
        case .decreaseFontSize: return L10n.commandSmaller
        case .actualFontSize: return L10n.commandActualSize

        case .quickOpen: return L10n.commandQuickOpen
        case .moveFocusToWorkspaceBrowser: return L10n.commandFocusBrowser
        case .moveFocusToEditor: return L10n.commandFocusEditor
        case .openInTab: return L10n.commandOpenInTab
        case .openInNewWindow: return L10n.commandOpenInNewWindow
        case .showNextTab: return L10n.commandNextTab
        case .showPreviousTab: return L10n.commandPreviousTab
        case .reopenClosedTab: return L10n.commandReopenClosedTab

        case .toggleTypewriterMode: return L10n.commandTypewriterMode
        case .toggleFocusMode: return L10n.commandFocusMode
        case .toggleSpellChecking: return L10n.commandCheckSpellingWhileTyping
        case .runWritingCheck: return L10n.commandRunWritingCheck

        case .keyboardShortcuts: return L10n.commandKeyboardShortcuts
        }
    }

    var action: Selector {
        switch self {
        case .newDocument: return #selector(NSDocumentController.newDocument(_:))
        case .openDocument: return #selector(NSDocumentController.openDocument(_:))
        case .openWorkspaceFolder: return #selector(AppDelegate.openWorkspaceFolder(_:))
        case .closeTab: return #selector(NSWindow.performClose(_:))
        case .save: return #selector(NSDocument.save(_:))
        case .saveAs: return #selector(NSDocument.saveAs(_:))
        case .revert: return #selector(NSDocument.revertToSaved(_:))
        case .revealInFinder: return #selector(AppDelegate.revealCurrentDocumentInFinder(_:))
        case .print: return #selector(NSDocument.printDocument(_:))

        case .toggleWorkspaceBrowser: return #selector(DocumentWindowController.toggleWorkspaceBrowser(_:))
        case .toggleWordCount: return #selector(AppDelegate.toggleWordCount(_:))
        case .themeLight, .themeDark, .themeGreenScreen: return #selector(AppDelegate.selectTheme(_:))
        case .increaseFontSize: return #selector(AppDelegate.increaseFontSize(_:))
        case .decreaseFontSize: return #selector(AppDelegate.decreaseFontSize(_:))
        case .actualFontSize: return #selector(AppDelegate.actualFontSize(_:))

        case .quickOpen: return #selector(AppDelegate.showQuickOpen(_:))
        case .moveFocusToWorkspaceBrowser: return #selector(DocumentWindowController.moveFocusToWorkspaceBrowser(_:))
        case .moveFocusToEditor: return #selector(DocumentWindowController.moveFocusToEditor(_:))
        case .openInTab: return #selector(DocumentWindowController.openSelectedFileInTab(_:))
        case .openInNewWindow: return #selector(DocumentWindowController.openSelectedFileInNewWindow(_:))
        case .showNextTab: return #selector(NSWindow.selectNextTab(_:))
        case .showPreviousTab: return #selector(NSWindow.selectPreviousTab(_:))
        case .reopenClosedTab: return #selector(AppDelegate.reopenClosedTab(_:))

        case .toggleTypewriterMode: return #selector(AppDelegate.toggleTypewriterMode(_:))
        case .toggleFocusMode: return #selector(AppDelegate.toggleFocusMode(_:))
        case .toggleSpellChecking: return #selector(NSTextView.toggleContinuousSpellChecking(_:))
        case .runWritingCheck: return #selector(AppDelegate.runWritingCheck(_:))

        case .keyboardShortcuts: return #selector(AppDelegate.showKeyboardShortcuts(_:))
        }
    }

    var shortcut: Shortcut? {
        switch self {
        // Established macOS commands keep their established keys.
        case .newDocument: return Shortcut("n")
        case .openDocument: return Shortcut("o")
        case .closeTab: return Shortcut("w")
        case .save: return Shortcut("s")
        case .saveAs: return Shortcut("s", [.command, .shift])
        case .print: return Shortcut("p")
        case .revert, .revealInFinder: return nil
        case .toggleSpellChecking: return nil

        // Paragraph's own commands.
        case .openWorkspaceFolder: return Shortcut("o", [.command, .option])
        case .toggleWorkspaceBrowser: return Shortcut("s", [.command, .option])
        case .toggleWordCount: return Shortcut("w", [.command, .control])
        case .themeLight, .themeDark, .themeGreenScreen: return nil
        case .increaseFontSize: return Shortcut("+")
        case .decreaseFontSize: return Shortcut("-")
        case .actualFontSize: return Shortcut("0")

        case .quickOpen: return Shortcut("o", [.command, .shift])
        case .moveFocusToWorkspaceBrowser: return Shortcut("1")
        case .moveFocusToEditor: return Shortcut("2")
        case .openInTab: return Shortcut("\r")
        case .openInNewWindow: return Shortcut("\r", [.command, .shift])
        case .showNextTab: return Shortcut("\t", [.control])
        case .showPreviousTab: return Shortcut("\t", [.control, .shift])
        case .reopenClosedTab: return Shortcut("t", [.command, .shift])

        case .toggleTypewriterMode: return Shortcut("t", [.command, .control])
        case .toggleFocusMode: return Shortcut("p", [.command, .control])
        case .runWritingCheck: return Shortcut("r", [.command, .control])

        case .keyboardShortcuts: return Shortcut("/")
        }
    }

    var category: ShortcutCategory {
        switch self {
        case .newDocument, .openDocument, .openWorkspaceFolder, .closeTab,
             .save, .saveAs, .revert, .revealInFinder, .print:
            return .file
        case .toggleWorkspaceBrowser, .toggleWordCount, .themeLight, .themeDark,
             .themeGreenScreen, .increaseFontSize, .decreaseFontSize, .actualFontSize:
            return .view
        case .quickOpen, .moveFocusToWorkspaceBrowser, .moveFocusToEditor,
             .openInTab, .openInNewWindow, .showNextTab, .showPreviousTab,
             .reopenClosedTab:
            return .navigate
        case .toggleTypewriterMode, .toggleFocusMode, .toggleSpellChecking,
             .runWritingCheck:
            return .writing
        case .keyboardShortcuts:
            return .help
        }
    }

    /// The theme a theme command selects, if it is one.
    var themeIdentifier: ThemeIdentifier? {
        switch self {
        case .themeLight: return .light
        case .themeDark: return .dark
        case .themeGreenScreen: return .greenScreen
        default: return nil
        }
    }

    func makeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: shortcut?.key ?? "")
        item.keyEquivalentModifierMask = shortcut?.modifiers ?? []
        item.representedObject = self
        return item
    }
}
