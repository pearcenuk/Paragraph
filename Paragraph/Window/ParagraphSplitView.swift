import AppKit

/// A split view whose divider stays visible in every theme.
///
/// AppKit's own divider colour is derived from the system appearance. In Green
/// Screen both sides of the split are nearly black, so the stock divider
/// disappears and the manuscript appears to run straight into the file list.
/// Drawing the theme's own separator colour keeps the boundary legible without
/// making it loud.
final class ParagraphSplitView: NSSplitView {

    override var dividerColor: NSColor {
        Preferences.shared.currentTheme.separator
    }

    override var dividerThickness: CGFloat {
        1
    }
}
