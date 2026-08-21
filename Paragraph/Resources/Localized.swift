import Foundation

/// Every string a writer can see, in one place.
///
/// Application logic refers to `L10n.somethingOrOther` and never to a literal,
/// so a translator only ever needs the string catalogue and never has to read
/// the source. Interface language follows the writer's macOS setting and is
/// independent of both the spell-checking language and any future
/// language-specific Writing Check rules.
enum L10n {

    // MARK: - Application

    static let applicationName = String(
        localized: "Paragraph",
        comment: "The name of the application. Usually left untranslated.")

    static let applicationDescription = String(
        localized: "Paragraph is a native macOS Markdown writing application focused on readability and distraction-free drafting.",
        comment: "One-line description of the application, shown in the About panel.")

    // MARK: - Menu titles

    static let menuFile = String(localized: "File", comment: "Menu bar title")
    static let menuEdit = String(localized: "Edit", comment: "Menu bar title")
    static let menuView = String(localized: "View", comment: "Menu bar title")
    static let menuNavigate = String(localized: "Navigate", comment: "Menu bar title")
    static let menuWriting = String(localized: "Writing", comment: "Menu bar title")
    static let menuWindow = String(localized: "Window", comment: "Menu bar title")
    static let menuHelp = String(localized: "Help", comment: "Menu bar title")

    static func about(_ name: String) -> String {
        String(localized: "About \(name)", comment: "Application menu item")
    }
    static func hide(_ name: String) -> String {
        String(localized: "Hide \(name)", comment: "Application menu item")
    }
    static func quit(_ name: String) -> String {
        String(localized: "Quit \(name)", comment: "Application menu item")
    }
    static let hideOthers = String(localized: "Hide Others", comment: "Application menu item")
    static let showAll = String(localized: "Show All", comment: "Application menu item")
    static let settings = String(localized: "Settings…", comment: "Application menu item")
    static let services = String(localized: "Services", comment: "Application menu item")

    // MARK: - Commands

    static let commandNew = String(localized: "New", comment: "File menu")
    static let commandOpen = String(localized: "Open…", comment: "File menu")
    static let commandOpenRecent = String(localized: "Open Recent", comment: "File menu")
    static let commandOpenWorkspace = String(localized: "Open Workspace Folder…", comment: "File menu")
    static let commandClose = String(localized: "Close", comment: "File menu")
    static let commandSave = String(localized: "Save", comment: "File menu")
    static let commandSaveAs = String(localized: "Save As…", comment: "File menu")
    static let commandRevert = String(localized: "Revert to Saved", comment: "File menu")
    static let commandRevealInFinder = String(localized: "Reveal in Finder", comment: "File menu")
    static let commandPrint = String(localized: "Print…", comment: "File menu")

    static let commandUndo = String(localized: "Undo", comment: "Edit menu")
    static let commandRedo = String(localized: "Redo", comment: "Edit menu")
    static let commandCut = String(localized: "Cut", comment: "Edit menu")
    static let commandCopy = String(localized: "Copy", comment: "Edit menu")
    static let commandPaste = String(localized: "Paste", comment: "Edit menu")
    static let commandDelete = String(localized: "Delete", comment: "Edit menu")
    static let commandSelectAll = String(localized: "Select All", comment: "Edit menu")
    static let commandFind = String(localized: "Find", comment: "Edit menu submenu title")
    static let commandFindEllipsis = String(localized: "Find…", comment: "Find submenu")
    static let commandFindReplace = String(localized: "Find and Replace…", comment: "Find submenu")
    static let commandFindNext = String(localized: "Find Next", comment: "Find submenu")
    static let commandFindPrevious = String(localized: "Find Previous", comment: "Find submenu")
    static let commandUseSelectionForFind = String(localized: "Use Selection for Find", comment: "Find submenu")
    static let commandSpelling = String(localized: "Spelling and Grammar", comment: "Edit menu submenu title")
    static let commandShowSpelling = String(localized: "Show Spelling and Grammar", comment: "Spelling submenu")
    static let commandCheckDocumentNow = String(localized: "Check Document Now", comment: "Spelling submenu")
    static let commandCheckSpellingWhileTyping = String(localized: "Check Spelling While Typing", comment: "Spelling submenu")
    static let commandSubstitutions = String(localized: "Substitutions", comment: "Edit menu submenu title")
    static let commandSmartQuotes = String(localized: "Smart Quotes", comment: "Substitutions submenu")
    static let commandSmartDashes = String(localized: "Smart Dashes", comment: "Substitutions submenu")

    static let commandTheme = String(localized: "Theme", comment: "View menu submenu title")
    static let commandToggleWorkspaceBrowser = String(localized: "Workspace Browser", comment: "View menu; a checked item")
    static let commandToggleWordCount = String(localized: "Word Count", comment: "View menu; a checked item")
    static let commandFullScreen = String(localized: "Enter Full Screen", comment: "View menu")
    static let commandBigger = String(localized: "Bigger", comment: "View menu; increases the text size")
    static let commandSmaller = String(localized: "Smaller", comment: "View menu; decreases the text size")
    static let commandActualSize = String(localized: "Actual Size", comment: "View menu; restores the default text size")

    static let commandQuickOpen = String(localized: "Quick Open…", comment: "Navigate menu")
    static let commandFocusBrowser = String(localized: "Move Focus to Workspace Browser", comment: "Navigate menu")
    static let commandFocusEditor = String(localized: "Move Focus to Editor", comment: "Navigate menu")
    static let commandOpenInTab = String(localized: "Open in Tab", comment: "Navigate menu and browser context menu")
    static let commandOpenInNewWindow = String(localized: "Open in New Window", comment: "Navigate menu and browser context menu")
    static let commandNextTab = String(localized: "Show Next Tab", comment: "Navigate menu")
    static let commandPreviousTab = String(localized: "Show Previous Tab", comment: "Navigate menu")
    static let commandReopenClosedTab = String(localized: "Reopen Closed Tab", comment: "Navigate menu")

    static let commandTypewriterMode = String(localized: "Typewriter Mode", comment: "Writing menu; a checked item")
    static let commandFocusMode = String(localized: "Focus Mode", comment: "Writing menu; a checked item")
    static let commandRunWritingCheck = String(localized: "Run Writing Check", comment: "Writing menu")
    static let commandShowWritingCheckResults = String(localized: "Show Writing Check Results", comment: "Writing menu")

    static let commandMinimise = String(localized: "Minimise", comment: "Window menu")
    static let commandZoom = String(localized: "Zoom", comment: "Window menu")
    static let commandBringAllToFront = String(localized: "Bring All to Front", comment: "Window menu")
    static let commandKeyboardShortcuts = String(localized: "Keyboard Shortcuts", comment: "Help menu")

    // MARK: - Themes

    static let themeLight = String(localized: "Light", comment: "Theme name")
    static let themeDark = String(localized: "Dark", comment: "Theme name")
    static let themeGreenScreen = String(localized: "Green Screen", comment: "Theme name")

    // MARK: - Word count

    static func wordCount(_ count: Int) -> String {
        String(
            localized: "\(count) words",
            comment: "Word count shown at the bottom of the editor. Uses plural rules.")
    }

    // MARK: - Workspace browser

    static let workspaceBrowser = String(localized: "Workspace Browser", comment: "Accessibility label for the file list")
    static let noWorkspace = String(localized: "No workspace folder is open.", comment: "Empty state in the workspace browser")
    static let noWorkspaceHint = String(localized: "Choose a folder to browse its Markdown files without leaving Paragraph.", comment: "Empty state explanation")
    static let chooseWorkspace = String(localized: "Choose Folder…", comment: "Button in the workspace browser empty state")
    static let emptyWorkspace = String(localized: "This folder contains no Markdown or text files.", comment: "Empty state when a workspace has no supported files")
    static let workspaceUnavailable = String(localized: "This folder is not available at the moment.", comment: "Shown when a workspace folder cannot be reached")

    static let contextNewFile = String(localized: "New File…", comment: "Workspace browser context menu")
    static let newFileTitle = String(localized: "New File", comment: "Title of the sheet that names a new file")
    static func newFileInFolder(_ folder: String) -> String {
        String(localized: "Create a new file in “\(folder)”.", comment: "Explains where a new file will be created")
    }
    static let newFileButton = String(localized: "Create", comment: "Confirms creating a new file")
    static let newFileDefaultName = String(localized: "Untitled", comment: "Default name for a new file, without its extension")
    static func newFileExists(_ name: String) -> String {
        String(localized: "“\(name)” already exists in this folder.", comment: "Alert when a new file would overwrite one")
    }
    static let newFileExistsDetail = String(localized: "Choose a different name.", comment: "Alert detail")

    static let contextRename = String(localized: "Rename…", comment: "Workspace browser context menu")
    static let contextRevealInFinder = String(localized: "Reveal in Finder", comment: "Workspace browser context menu")
    static let contextMoveToTrash = String(localized: "Move to Trash", comment: "Workspace browser context menu")

    static let itemNotDownloaded = String(localized: "Not downloaded from iCloud", comment: "Accessibility description for an item still in the cloud")
    static let itemDownloading = String(localized: "Downloading from iCloud", comment: "Accessibility description for an item being fetched")

    // MARK: - Quick Open

    static let quickOpenPlaceholder = String(localized: "Open Quickly", comment: "Placeholder in the Quick Open field")
    static let quickOpenNoMatches = String(localized: "No matching files", comment: "Quick Open empty result")
    static let quickOpenHint = String(localized: "Return opens in a tab. Shift-Return opens in a new window.", comment: "Quick Open footer hint")

    // MARK: - Settings

    static let settingsTitle = String(localized: "Settings", comment: "Settings window title")
    static let settingsTheme = String(localized: "Theme:", comment: "Settings label")
    static let settingsRestoreSession = String(localized: "Restore the previous session at launch", comment: "Settings checkbox")
    static let settingsRestoreSessionHelp = String(localized: "Reopens your workspace, windows and tabs, and returns you to roughly where you left off.", comment: "Settings explanation")
    static let settingsSpellChecking = String(localized: "Check spelling while typing", comment: "Settings checkbox")
    static let settingsSpellCheckingHelp = String(localized: "Uses the spelling languages configured in macOS System Settings.", comment: "Settings explanation")

    // MARK: - Keyboard Shortcuts window

    static let shortcutsTitle = String(localized: "Keyboard Shortcuts", comment: "Window title")
    static let shortcutsIntro = String(localized: "Every command is also available from the menus.", comment: "Introductory line in the shortcuts window")

    // MARK: - Writing Check

    static let writingCheckTitle = String(localized: "Writing Check", comment: "Window title")
    static let writingCheckClean = String(localized: "Nothing to report.", comment: "Writing Check found no issues")
    static let writingCheckCleanDetail = String(localized: "Writing Check looks for mechanical slips only. It does not judge your writing.", comment: "Explanation shown alongside a clean result")
    static let writingCheckNoDocument = String(localized: "Open a document to run Writing Check.", comment: "Writing Check with no document")
    static let severityError = String(localized: "Error", comment: "Writing Check severity")
    static let severityWarning = String(localized: "Warning", comment: "Writing Check severity")

    /// Composed from two independently pluralised counts, because a single
    /// string with two numbers in it cannot be pluralised correctly in every
    /// language — nor, as the compiler points out, unambiguously in English.
    static func errorCount(_ count: Int) -> String {
        String(localized: "\(count) errors", comment: "Writing Check error count. Uses plural rules.")
    }
    static func warningCount(_ count: Int) -> String {
        String(localized: "\(count) warnings", comment: "Writing Check warning count. Uses plural rules.")
    }
    static func writingCheckSummary(errors: Int, warnings: Int) -> String {
        let errorPart = errorCount(errors)
        let warningPart = warningCount(warnings)
        return String(
            localized: "\(errorPart), \(warningPart)",
            comment: "Joins the Writing Check error and warning counts.")
    }
    static func lineLabel(_ line: Int) -> String {
        String(localized: "Line \(line)", comment: "Location of a Writing Check result")
    }

    static func unmatchedOpeningQuote(_ mark: String) -> String {
        String(localized: "Opening quotation mark \(mark) is never closed.", comment: "Writing Check result")
    }
    static func unmatchedClosingQuote(_ mark: String) -> String {
        String(localized: "Closing quotation mark \(mark) has no opening mark.", comment: "Writing Check result")
    }
    static func unmatchedOpeningDelimiter(_ mark: String) -> String {
        String(localized: "Opening \(mark) is never closed.", comment: "Writing Check result for a bracket")
    }
    static func unmatchedClosingDelimiter(_ mark: String) -> String {
        String(localized: "Closing \(mark) has no opening mark.", comment: "Writing Check result for a bracket")
    }
    static func duplicateWord(_ word: String) -> String {
        String(localized: "“\(word)” appears twice in a row.", comment: "Writing Check result")
    }
    static func repeatedPhrase(_ phrase: String) -> String {
        String(localized: "“\(phrase)” was used again close by.", comment: "Writing Check result")
    }

    // MARK: - File handling

    static let untitledDocument = String(localized: "Untitled", comment: "Name for a document that has never been saved")

    static let externalChangeTitle = String(localized: "This file was changed by another application.", comment: "Banner shown when a file changes on disk")
    static let externalChangeDetail = String(localized: "Your unsaved edits are still here. Saving will replace the version on disk.", comment: "Banner detail")
    static let externalChangeReload = String(localized: "Reload from Disk", comment: "Banner button")
    static let externalChangeKeep = String(localized: "Keep My Version", comment: "Banner button")

    static let downloadingFromCloud = String(localized: "Downloading from iCloud…", comment: "Editor banner while a file is fetched")

    static func missingFileTitle(_ name: String) -> String {
        String(localized: "“\(name)” could not be opened.", comment: "Alert title when a restored file is gone")
    }
    static let missingFileDetail = String(localized: "It may have been moved, renamed or deleted since you last used Paragraph.", comment: "Alert detail")
    static let missingFileLocate = String(localized: "Locate…", comment: "Alert button")
    static let missingFileRemove = String(localized: "Remove from Session", comment: "Alert button")

    static func trashConfirmTitle(_ name: String) -> String {
        String(localized: "Move “\(name)” to the Trash?", comment: "Confirmation alert")
    }
    static let trashConfirmDetail = String(localized: "You can put it back from the Trash.", comment: "Confirmation alert detail")
    static let trashConfirmButton = String(localized: "Move to Trash", comment: "Confirmation button")

    static let renameTitle = String(localized: "Rename", comment: "Rename sheet title")
    static let renameButton = String(localized: "Rename", comment: "Rename sheet confirm button")

    static let clearMenu = String(localized: "Clear Menu", comment: "Clears the Open Recent list")
    static let cancel = String(localized: "Cancel", comment: "Generic cancel button")
    static let ok = String(localized: "OK", comment: "Generic confirm button")
    static let close = String(localized: "Close", comment: "Generic close button")
    static let done = String(localized: "Done", comment: "Generic done button")

    static let openWorkspacePrompt = String(localized: "Choose Workspace", comment: "Confirm button in the folder chooser")
    static let openWorkspaceMessage = String(localized: "Choose a folder to browse in Paragraph.", comment: "Message in the folder chooser")
}
