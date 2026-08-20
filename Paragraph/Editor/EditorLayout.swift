import AppKit

/// The geometry of the writing column.
///
/// The column is centred in the editor; the prose inside it stays left aligned.
/// There is no slider, no margin setting and no alignment preference: the
/// measure is a decision Paragraph has made.
enum EditorLayout {

    /// How wide the column should be for a given editor width.
    ///
    /// On a large display the column stops growing, so a line never becomes a
    /// tiring sweep of the eye. In a narrow window it gives up its padding
    /// gracefully rather than clipping the text.
    static func columnWidth(availableWidth: CGFloat, font: NSFont) -> CGFloat {
        let preferred = EditorTypography.preferredColumnWidth(for: font)
        let usable = availableWidth - (EditorTypography.horizontalPadding * 2)
        return max(120, min(preferred, usable))
    }

    /// The inset that keeps the column centred. Applied symmetrically by
    /// `NSTextView`, so it is half the leftover space.
    static func horizontalInset(availableWidth: CGFloat, columnWidth: CGFloat) -> CGFloat {
        max(EditorTypography.horizontalPadding, (availableWidth - columnWidth) / 2)
    }
}
