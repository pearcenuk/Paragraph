import AppKit
import ParagraphKit

/// Draws Markdown emphasis in the editor without hiding the markers.
///
/// `**loud**` is set bold with its asterisks still visible, dimmed. Nothing
/// moves, appears or disappears as the cursor travels over it, which is the
/// difference between syntax colouring and a hidden-Markdown editor.
///
/// Styling is applied as *attributes* on the shared `NSTextStorage`. Attributes
/// are not characters: only `textStorage.string` is ever written to disk, and
/// only a change to the characters marks a document edited. Styling therefore
/// cannot alter a file, and it costs nothing in the undo stack.
enum MarkdownStyler {

    /// Restyles `range`, or the whole document when `range` is `nil`.
    ///
    /// The range is widened to whole lines first, because emphasis is matched
    /// within a line and a partial line would produce partial styling.
    static func apply(
        to storage: NSTextStorage,
        theme: Theme,
        range: NSRange? = nil
    ) {
        let text = storage.string
        let full = NSRange(location: 0, length: storage.length)
        let target = (range.map { lineRange(in: text, covering: $0) } ?? full)
            .intersection(full) ?? full
        guard target.length > 0 || storage.length == 0 else { return }

        let body = EditorTypography.bodyFont()
        let base = MarkdownDocument.attributes(for: theme)

        storage.beginEditing()
        storage.setAttributes(base, range: target)

        guard let slice = Range(target, in: text) else {
            storage.endEditing()
            return
        }

        for span in MarkdownStyleScanner.spans(in: String(text[slice])) {
            guard let spanRange = nsRange(of: span, within: slice, in: text, offset: target.location)
            else { continue }

            switch span.kind {
            case .marker:
                // Present, but out of the way.
                storage.addAttribute(.foregroundColor, value: theme.markerText, range: spanRange)

            case .emphasis:
                storage.addAttribute(.font, value: variant(of: body, italic: true), range: spanRange)

            case .strong:
                storage.addAttribute(.font, value: variant(of: body, bold: true), range: spanRange)

            case .strongEmphasis:
                storage.addAttribute(
                    .font,
                    value: variant(of: body, bold: true, italic: true),
                    range: spanRange
                )

            case .strikethrough:
                storage.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: spanRange
                )
                storage.addAttribute(.strikethroughColor, value: theme.markerText, range: spanRange)

            case .code:
                storage.addAttribute(
                    .font,
                    value: NSFont.monospacedSystemFont(ofSize: body.pointSize * 0.94, weight: .regular),
                    range: spanRange
                )
                storage.addAttribute(.foregroundColor, value: theme.codeText, range: spanRange)

            case .heading(let level):
                storage.addAttribute(
                    .font,
                    value: variant(of: body, bold: true, scale: headingScale(level)),
                    range: spanRange
                )
            }
        }
        storage.endEditing()
    }

    // MARK: - Fonts

    /// Headings lift slightly rather than shouting. A chapter title is a
    /// signpost, not a billboard.
    private static func headingScale(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 1.28
        case 2: return 1.16
        case 3: return 1.07
        default: return 1.0
        }
    }

    private static func variant(
        of font: NSFont,
        bold: Bool = false,
        italic: Bool = false,
        scale: CGFloat = 1
    ) -> NSFont {
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }

        let size = (font.pointSize * scale).rounded()
        let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
        if let styled = NSFont(descriptor: descriptor, size: size) {
            return styled
        }
        // The bundled family lacks the face; let AppKit synthesise rather than
        // silently drop the emphasis.
        return NSFont(descriptor: font.fontDescriptor, size: size) ?? font
    }

    // MARK: - Ranges

    private static func lineRange(in text: String, covering range: NSRange) -> NSRange {
        (text as NSString).lineRange(for: range)
    }

    private static func nsRange(
        of span: MarkdownStyleSpan,
        within slice: Range<String.Index>,
        in text: String,
        offset: Int
    ) -> NSRange? {
        // Spans are measured against the slice that was scanned, so their UTF-16
        // offsets are relative to it.
        let sliceText = String(text[slice])
        guard let range = Range(NSRange(span.range, in: sliceText), in: sliceText) else { return nil }
        let local = NSRange(range, in: sliceText)
        return NSRange(location: offset + local.location, length: local.length)
    }
}
