import AppKit
import Combine

/// Keeps a window's appearance in step with the chosen theme.
///
/// The main window is themed by its own controller. Paragraph's smaller
/// windows — Writing Check, Keyboard Shortcuts, Settings, Quick Open — would
/// otherwise follow the system setting and turn up dark beside a Light
/// manuscript.
final class ThemeAppearanceBinder {
    private var observer: AnyCancellable?

    init(window: NSWindow?) {
        guard let window else { return }
        window.appearance = Preferences.shared.currentTheme.appearance
        observer = Preferences.shared.$theme
            .receive(on: RunLoop.main)
            .sink { [weak window] identifier in
                window?.appearance = identifier.theme.appearance
            }
    }
}
