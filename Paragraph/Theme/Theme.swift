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
    /// The browser's background. Every theme supplies one rather than using the
    /// system's translucent sidebar material: that material samples the desktop
    /// behind the window, so a coloured wallpaper tinted the file list and the
    /// theme stopped being the thing deciding what the writer sees.
    let sidebarBackground: NSColor

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
                sidebarBackground: NSColor(white: 0.955, alpha: 1)
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
                sidebarBackground: NSColor(white: 0.105, alpha: 1)
            )

        case .greenScreen:
            // A dark room and green text, and nothing else. No scan lines, no
            // glow, no curvature: those would be decoration, and decoration is
            // not writing.
            return Theme(
                identifier: .greenScreen,
                appearanceName: .darkAqua,
                editorBackground: NSColor(srgbRed: 0.039, green: 0.055, blue: 0.039, alpha: 1),
                bodyText: NSColor(srgbRed: 0.600, green: 0.870, blue: 0.600, alpha: 1),
                deEmphasisedText: NSColor(srgbRed: 0.310, green: 0.450, blue: 0.310, alpha: 1),
                insertionPoint: NSColor(srgbRed: 0.706, green: 0.949, blue: 0.706, alpha: 1),
                selectionBackground: NSColor(srgbRed: 0.129, green: 0.259, blue: 0.129, alpha: 1),
                secondaryText: NSColor(srgbRed: 0.435, green: 0.612, blue: 0.435, alpha: 1),
                separator: NSColor(srgbRed: 0.176, green: 0.271, blue: 0.176, alpha: 1),
                sidebarBackground: NSColor(srgbRed: 0.020, green: 0.031, blue: 0.020, alpha: 1)
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
