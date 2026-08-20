import AppKit
import Combine

/// Everything Paragraph remembers between launches that is not a window.
///
/// Settings are deliberately few. View state such as Focus Mode or word-count
/// visibility lives here too because a writer expects the application to come
/// back the way they left it, but none of it is exposed in Settings: those are
/// modes toggled from the menus, not preferences to be configured.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let theme = "theme"
        static let restoreSession = "restorePreviousSession"
        static let spellChecking = "spellCheckingEnabled"
        static let typewriterMode = "typewriterMode"
        static let focusMode = "focusMode"
        static let wordCountVisible = "wordCountVisible"
        static let workspaceBookmark = "workspaceBookmark"
        static let expandedFolders = "expandedFolders"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.theme: ThemeIdentifier.light.rawValue,
            Key.restoreSession: true,
            Key.spellChecking: true,
            Key.typewriterMode: false,
            Key.focusMode: false,
            Key.wordCountVisible: true
        ])
        theme = ThemeIdentifier(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .light
        restorePreviousSession = defaults.bool(forKey: Key.restoreSession)
        spellCheckingEnabled = defaults.bool(forKey: Key.spellChecking)
        typewriterMode = defaults.bool(forKey: Key.typewriterMode)
        focusMode = defaults.bool(forKey: Key.focusMode)
        wordCountVisible = defaults.bool(forKey: Key.wordCountVisible)
    }

    // MARK: - Settings

    @Published var theme: ThemeIdentifier {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    @Published var restorePreviousSession: Bool {
        didSet { defaults.set(restorePreviousSession, forKey: Key.restoreSession) }
    }

    @Published var spellCheckingEnabled: Bool {
        didSet { defaults.set(spellCheckingEnabled, forKey: Key.spellChecking) }
    }

    // MARK: - Restored view state

    @Published var typewriterMode: Bool {
        didSet { defaults.set(typewriterMode, forKey: Key.typewriterMode) }
    }

    @Published var focusMode: Bool {
        didSet { defaults.set(focusMode, forKey: Key.focusMode) }
    }

    @Published var wordCountVisible: Bool {
        didSet { defaults.set(wordCountVisible, forKey: Key.wordCountVisible) }
    }

    // MARK: - Workspace

    /// Security-scoped bookmark for the folder the writer last chose. Storing a
    /// bookmark rather than a path is what lets a sandboxed Paragraph reopen an
    /// iCloud Drive folder without asking again.
    var workspaceBookmark: Data? {
        get { defaults.data(forKey: Key.workspaceBookmark) }
        set { defaults.set(newValue, forKey: Key.workspaceBookmark) }
    }

    /// Relative paths of folders the writer had expanded in the browser.
    var expandedFolders: [String] {
        get { defaults.stringArray(forKey: Key.expandedFolders) ?? [] }
        set { defaults.set(newValue, forKey: Key.expandedFolders) }
    }

    var currentTheme: Theme { theme.theme }
}
