import AppKit

/// The single, opinionated set of type decisions Paragraph makes.
///
/// There is no font picker, no size stepper and no line-width slider. The
/// measure is derived from the font rather than hard-coded in points, so it
/// stays correct if the body size changes for accessibility reasons.
enum EditorTypography {

    /// IBM Plex Sans, shipped with the application. An open, level humanist
    /// sans that stays comfortable over a long session.
    ///
    /// Falls back to the system font if registration failed, so a missing file
    /// degrades to something readable rather than to something arbitrary.
    static func bodyFont(size: CGFloat? = nil) -> NSFont {
        let pointSize = size ?? bodyPointSize
        BundledFonts.register()
        if let font = NSFont(name: BundledFonts.writingFontFamily, size: pointSize) {
            return font
        }
        return NSFont.systemFont(ofSize: pointSize)
    }

    /// The writer's current text size. Changed with Bigger and Smaller, and
    /// reset with Actual Size — the same three commands every Mac text
    /// application has. There is no font picker and no size field.
    static var bodyPointSize: CGFloat {
        CGFloat(Preferences.shared.editorFontSize)
    }

    static let defaultPointSize: Double = 17
    static let minimumPointSize: Double = 11
    static let maximumPointSize: Double = 32
    static let pointSizeStep: Double = 1

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
