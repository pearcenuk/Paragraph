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

    /// Markdown punctuation: visible, but receding so the prose reads first.
    var markerText: NSColor { secondaryText }

    /// Inline code and fenced blocks.
    var codeText: NSColor { secondaryText }

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
            // not writing. The green is a saturated phosphor rather than a pale
            // mint — brighter in hue, a little darker in value, still 10:1
            // against its background.
            return Theme(
                identifier: .greenScreen,
                appearanceName: .darkAqua,
                editorBackground: NSColor(srgbRed: 0.039, green: 0.055, blue: 0.039, alpha: 1),
                bodyText: NSColor(srgbRed: 0.431, green: 0.816, blue: 0.431, alpha: 1),
                deEmphasisedText: NSColor(srgbRed: 0.282, green: 0.471, blue: 0.298, alpha: 1),
                insertionPoint: NSColor(srgbRed: 0.510, green: 0.910, blue: 0.510, alpha: 1),
                selectionBackground: NSColor(srgbRed: 0.118, green: 0.259, blue: 0.125, alpha: 1),
                secondaryText: NSColor(srgbRed: 0.376, green: 0.620, blue: 0.392, alpha: 1),
                separator: NSColor(srgbRed: 0.157, green: 0.267, blue: 0.165, alpha: 1),
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
