import AppKit

/// Paragraph ships exactly three themes. There is no theme editor, no colour
/// picker and no import mechanism: choosing colours is the application's job,
/// not the writer's.
enum ThemeIdentifier: String, CaseIterable, Codable {
    case light
    case dark
    case greenScreen

    var theme: Theme { Theme.theme(for: self) }
}

/// The colours a theme supplies to the editor and its chrome.
///
/// Every value is checked for contrast: body text sits at 9:1 or better against
/// its background, and the de-emphasised colour Focus Mode uses stays above 3:1
/// so surrounding paragraphs remain readable rather than merely visible.
struct Theme {
    let identifier: ThemeIdentifier
    let appearanceName: NSAppearance.Name

    let editorBackground: NSColor
    let bodyText: NSColor
    /// Used by Focus Mode for paragraphs the writer is not currently in.
    let deEmphasisedText: NSColor
    let insertionPoint: NSColor
    let selectionBackground: NSColor
    /// Word-count bar and other quiet chrome.
    let secondaryText: NSColor
    let separator: NSColor
    /// `nil` means "use the system sidebar material", which is what Light and
    /// Dark do so the window looks like every other Mac window.
    let sidebarBackground: NSColor?

    var appearance: NSAppearance? { NSAppearance(named: appearanceName) }

    static func theme(for identifier: ThemeIdentifier) -> Theme {
        switch identifier {
        case .light:
            return Theme(
                identifier: .light,
                appearanceName: .aqua,
                editorBackground: NSColor(white: 0.99, alpha: 1),
                bodyText: NSColor(white: 0.15, alpha: 1),
                deEmphasisedText: NSColor(white: 0.55, alpha: 1),
                insertionPoint: NSColor(white: 0.10, alpha: 1),
                selectionBackground: NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.93, alpha: 1),
                secondaryText: NSColor(white: 0.45, alpha: 1),
                separator: NSColor(white: 0.88, alpha: 1),
                sidebarBackground: nil
            )

        case .dark:
            return Theme(
                identifier: .dark,
                appearanceName: .darkAqua,
                editorBackground: NSColor(white: 0.13, alpha: 1),
                bodyText: NSColor(white: 0.85, alpha: 1),
                deEmphasisedText: NSColor(white: 0.45, alpha: 1),
                insertionPoint: NSColor(white: 0.92, alpha: 1),
                selectionBackground: NSColor(calibratedRed: 0.22, green: 0.28, blue: 0.36, alpha: 1),
                secondaryText: NSColor(white: 0.58, alpha: 1),
                separator: NSColor(white: 0.24, alpha: 1),
                sidebarBackground: nil
            )

        case .greenScreen:
            // A dark room and green text, and nothing else. No scan lines, no
            // glow, no curvature: those would be decoration, and decoration is
            // not writing.
            return Theme(
                identifier: .greenScreen,
                appearanceName: .darkAqua,
                editorBackground: NSColor(srgbRed: 0.039, green: 0.055, blue: 0.039, alpha: 1),
                bodyText: NSColor(srgbRed: 0.561, green: 0.761, blue: 0.561, alpha: 1),
                deEmphasisedText: NSColor(srgbRed: 0.290, green: 0.420, blue: 0.290, alpha: 1),
                insertionPoint: NSColor(srgbRed: 0.659, green: 0.878, blue: 0.659, alpha: 1),
                selectionBackground: NSColor(srgbRed: 0.118, green: 0.227, blue: 0.118, alpha: 1),
                secondaryText: NSColor(srgbRed: 0.400, green: 0.549, blue: 0.400, alpha: 1),
                separator: NSColor(srgbRed: 0.106, green: 0.153, blue: 0.106, alpha: 1),
                sidebarBackground: NSColor(srgbRed: 0.027, green: 0.039, blue: 0.027, alpha: 1)
            )
        }
    }

    var localizedName: String {
        switch identifier {
        case .light: return L10n.themeLight
        case .dark: return L10n.themeDark
        case .greenScreen: return L10n.themeGreenScreen
        }
    }
}
