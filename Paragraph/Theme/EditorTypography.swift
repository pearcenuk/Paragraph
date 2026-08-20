import AppKit

/// The single, opinionated set of type decisions Paragraph makes.
///
/// There is no font picker, no size stepper and no line-width slider. The
/// measure is derived from the font rather than hard-coded in points, so it
/// stays correct if the body size changes for accessibility reasons.
enum EditorTypography {

    /// The system serif (New York). Chosen for long-form prose rather than a
    /// monospace, because Paragraph is for drafting chapters, not code.
    /// Falls back to the default system font if the serif design is missing.
    static func bodyFont() -> NSFont {
        let size = bodyPointSize
        let base = NSFont.systemFont(ofSize: size)
        guard let descriptor = base.fontDescriptor.withDesign(.serif),
              let serif = NSFont(descriptor: descriptor, size: size)
        else { return base }
        return serif
    }

    static let bodyPointSize: CGFloat = 17

    /// Line height as a multiple of the font size. Loose enough to read for
    /// hours without becoming double-spaced.
    static let lineHeightMultiple: CGFloat = 1.5

    /// Space between paragraphs, so a blank line is not needed to see structure.
    static let paragraphSpacing: CGFloat = 10

    /// The measure, in characters. Around 65 keeps the eye's return sweep short,
    /// which is the whole reason the writing column is capped at all.
    static let measureInCharacters: CGFloat = 66

    /// Comfortable breathing room either side of the text within its column.
    static let horizontalPadding: CGFloat = 28

    /// Space above the first line and below the last.
    static let verticalPadding: CGFloat = 32

    /// The width the writing column wants, measured from the font itself.
    static func preferredColumnWidth(for font: NSFont) -> CGFloat {
        let sample: NSString = "n"
        let advance = sample.size(withAttributes: [.font: font]).width
        let glyphWidth = advance > 0 ? advance : font.pointSize * 0.5
        return (glyphWidth * measureInCharacters).rounded()
    }

    static func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.paragraphSpacing = paragraphSpacing
        // Prose is left aligned. The *column* is centred, never the text.
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping
        return style
    }
}
