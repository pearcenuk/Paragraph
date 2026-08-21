import Foundation

/// What a stretch of Markdown source should look like in the editor.
///
/// Paragraph shows emphasis *and* its markers: `**loud**` is drawn bold with
/// the asterisks still there, dimmed. That is deliberately not a
/// hidden-Markdown editor — nothing moves or disappears as the cursor travels,
/// and what you see is still exactly what is in the file.
public enum MarkdownStyleKind: Equatable, Sendable {
    /// The punctuation itself: `**`, `_`, `` ` ``, `#`, `>`, a list bullet.
    case marker
    case emphasis
    case strong
    case strongEmphasis
    case strikethrough
    case code
    case heading(level: Int)
}

public struct MarkdownStyleSpan: Equatable, Sendable {
    public let kind: MarkdownStyleKind
    public let range: Range<String.Index>

    public init(kind: MarkdownStyleKind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
}

/// Finds the inline emphasis in Markdown source, along with the markers that
/// produce it.
///
/// This is a pragmatic scanner rather than a CommonMark implementation. It
/// handles the constructs that appear in manuscripts and deliberately declines
/// the exotic ones: when a run of punctuation is ambiguous it is left as plain
/// text, because a wrongly bolded half-paragraph is far more annoying than a
/// missed emphasis.
///
/// Rules it does enforce, because getting them wrong would be visible every day:
///
/// - `snake_case` and `file_name_here` are not italic. An underscore only opens
///   or closes emphasis at a word boundary; an asterisk may do so anywhere.
/// - `2 * 3 * 4` is not emphasis: a delimiter followed by whitespace cannot
///   open, and one preceded by whitespace cannot close.
/// - A backslash escape (`\*`) is never a delimiter.
/// - Nothing inside a code span or a fenced code block is styled.
public enum MarkdownStyleScanner {

    public static func spans(in text: String) -> [MarkdownStyleSpan] {
        var spans: [MarkdownStyleSpan] = []
        var inFence = false
        var fenceMarker: Character = "`"

        for line in lineRanges(in: text) {
            let trimmedStart = skipIndent(text, line)
            let content = trimmedStart..<line.upperBound

            if let fence = fenceRun(text, content) {
                if inFence, fence.marker == fenceMarker {
                    inFence = false
                } else if !inFence {
                    inFence = true
                    fenceMarker = fence.marker
                }
                spans.append(MarkdownStyleSpan(kind: .marker, range: line))
                continue
            }
            if inFence {
                spans.append(MarkdownStyleSpan(kind: .code, range: line))
                continue
            }

            var bodyStart = trimmedStart

            // Headings: the hashes are markers, the rest of the line is the
            // heading. Emphasis inside a heading is still scanned.
            if let heading = headingRun(text, content) {
                spans.append(MarkdownStyleSpan(kind: .marker, range: heading.markerRange))
                spans.append(
                    MarkdownStyleSpan(
                        kind: .heading(level: heading.level),
                        range: heading.markerRange.upperBound..<line.upperBound
                    )
                )
                bodyStart = heading.markerRange.upperBound
            } else if let blockMarker = blockMarkerRun(text, content) {
                spans.append(MarkdownStyleSpan(kind: .marker, range: blockMarker))
                bodyStart = blockMarker.upperBound
            }

            spans.append(contentsOf: scanInline(text, bodyStart..<line.upperBound))
        }
        return spans
    }

    // MARK: - Lines and block markers

    private static func lineRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "\n" {
                ranges.append(start..<index)
                start = text.index(after: index)
            }
            index = text.index(after: index)
        }
        if start < text.endIndex { ranges.append(start..<text.endIndex) }
        return ranges
    }

    private static func skipIndent(_ text: String, _ line: Range<String.Index>) -> String.Index {
        var index = line.lowerBound
        while index < line.upperBound, text[index] == " " || text[index] == "\t" {
            index = text.index(after: index)
        }
        return index
    }

    private static func fenceRun(
        _ text: String,
        _ range: Range<String.Index>
    ) -> (marker: Character, length: Int)? {
        guard let first = text[range].first, first == "`" || first == "~" else { return nil }
        let length = text[range].prefix { $0 == first }.count
        return length >= 3 ? (first, length) : nil
    }

    private static func headingRun(
        _ text: String,
        _ range: Range<String.Index>
    ) -> (level: Int, markerRange: Range<String.Index>)? {
        guard text[range].first == "#" else { return nil }
        let hashes = text[range].prefix { $0 == "#" }
        guard hashes.count <= 6 else { return nil }
        let after = text.index(range.lowerBound, offsetBy: hashes.count)
        guard after < range.upperBound, text[after] == " " else { return nil }
        return (hashes.count, range.lowerBound..<text.index(after: after))
    }

    /// Blockquote arrows and list bullets, which recede but stay put.
    private static func blockMarkerRun(
        _ text: String,
        _ range: Range<String.Index>
    ) -> Range<String.Index>? {
        guard let first = text[range].first else { return nil }

        if first == ">" {
            var index = text.index(after: range.lowerBound)
            while index < range.upperBound, text[index] == " " { index = text.index(after: index) }
            return range.lowerBound..<index
        }
        if first == "-" || first == "*" || first == "+" {
            let after = text.index(after: range.lowerBound)
            guard after < range.upperBound, text[after] == " " else { return nil }
            return range.lowerBound..<text.index(after: after)
        }
        if first.isNumber {
            let digits = text[range].prefix { $0.isNumber }
            let afterDigits = text.index(range.lowerBound, offsetBy: digits.count)
            guard afterDigits < range.upperBound,
                  text[afterDigits] == "." || text[afterDigits] == ")" else { return nil }
            let afterDelimiter = text.index(after: afterDigits)
            guard afterDelimiter < range.upperBound, text[afterDelimiter] == " " else { return nil }
            return range.lowerBound..<text.index(after: afterDelimiter)
        }
        return nil
    }

    // MARK: - Inline

    private static func scanInline(
        _ text: String,
        _ range: Range<String.Index>
    ) -> [MarkdownStyleSpan] {
        var spans: [MarkdownStyleSpan] = []
        var index = range.lowerBound

        while index < range.upperBound {
            let character = text[index]

            if character == "\\" {
                index = text.index(index, offsetBy: 2, limitedBy: range.upperBound)
                    ?? range.upperBound
                continue
            }

            if character == "`" {
                if let span = codeSpan(text, from: index, limit: range.upperBound) {
                    spans.append(contentsOf: span.spans)
                    index = span.end
                    continue
                }
            }

            if character == "*" || character == "_" || character == "~" {
                if let span = emphasisSpan(text, from: index, limit: range.upperBound) {
                    spans.append(contentsOf: span.spans)
                    index = span.end
                    continue
                }
            }
            index = text.index(after: index)
        }
        return spans
    }

    private static func codeSpan(
        _ text: String,
        from open: String.Index,
        limit: String.Index
    ) -> (spans: [MarkdownStyleSpan], end: String.Index)? {
        let ticks = text[open..<limit].prefix { $0 == "`" }.count
        let fence = String(repeating: "`", count: ticks)
        let contentStart = text.index(open, offsetBy: ticks)
        guard contentStart < limit,
              let close = text.range(of: fence, range: contentStart..<limit)
        else { return nil }

        return ([
            MarkdownStyleSpan(kind: .marker, range: open..<contentStart),
            MarkdownStyleSpan(kind: .code, range: contentStart..<close.lowerBound),
            MarkdownStyleSpan(kind: .marker, range: close)
        ], close.upperBound)
    }

    private static func emphasisSpan(
        _ text: String,
        from open: String.Index,
        limit: String.Index
    ) -> (spans: [MarkdownStyleSpan], end: String.Index)? {
        let delimiter = text[open]
        let runLength = text[open..<limit].prefix { $0 == delimiter }.count

        if delimiter == "~" { guard runLength == 2 else { return nil } }
        guard runLength <= 3 else { return nil }

        let contentStart = text.index(open, offsetBy: runLength)
        guard contentStart < limit else { return nil }

        // A delimiter followed by whitespace cannot open: `2 * 3` is arithmetic.
        guard !text[contentStart].isWhitespace else { return nil }
        // `_` only opens at a word boundary, so `snake_case` stays upright.
        if delimiter == "_", open > text.startIndex,
           isWordCharacter(text[text.index(before: open)]) { return nil }

        guard let close = closingRun(
            text, delimiter: delimiter, length: runLength,
            from: contentStart, limit: limit
        ) else { return nil }

        let kind: MarkdownStyleKind
        switch (delimiter, runLength) {
        case ("~", _): kind = .strikethrough
        case (_, 1): kind = .emphasis
        case (_, 2): kind = .strong
        default: kind = .strongEmphasis
        }

        return ([
            MarkdownStyleSpan(kind: .marker, range: open..<contentStart),
            MarkdownStyleSpan(kind: kind, range: contentStart..<close.lowerBound),
            MarkdownStyleSpan(kind: .marker, range: close)
        ], close.upperBound)
    }

    private static func closingRun(
        _ text: String,
        delimiter: Character,
        length: Int,
        from start: String.Index,
        limit: String.Index
    ) -> Range<String.Index>? {
        var index = start
        while index < limit {
            if text[index] == "\\" {
                index = text.index(index, offsetBy: 2, limitedBy: limit) ?? limit
                continue
            }
            guard text[index] == delimiter else {
                index = text.index(after: index)
                continue
            }
            let run = text[index..<limit].prefix { $0 == delimiter }.count
            guard run == length else {
                index = text.index(index, offsetBy: run, limitedBy: limit) ?? limit
                continue
            }
            // A delimiter preceded by whitespace cannot close, and content must
            // not be empty.
            let before = text[text.index(before: index)]
            guard index > start, !before.isWhitespace else {
                index = text.index(index, offsetBy: run, limitedBy: limit) ?? limit
                continue
            }
            if delimiter == "_" {
                let after = text.index(index, offsetBy: run, limitedBy: limit) ?? limit
                if after < limit, isWordCharacter(text[after]) {
                    index = after
                    continue
                }
            }
            return index..<(text.index(index, offsetBy: run, limitedBy: limit) ?? limit)
        }
        return nil
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
