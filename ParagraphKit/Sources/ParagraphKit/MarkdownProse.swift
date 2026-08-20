import Foundation

/// A contiguous run of characters from the original Markdown source that
/// Paragraph considers to be prose rather than markup.
///
/// Runs keep their `Range<String.Index>` into the *original* text so that both
/// the word counter and Writing Check can report positions the editor can
/// select without re-deriving offsets.
public struct ProseRun: Equatable, Sendable {
    public let range: Range<String.Index>

    /// `true` when whitespace (or a line break, or the start of the document)
    /// separated this run from the preceding run.
    ///
    /// When `false` the run continues the previous run's final word, which is
    /// what makes `un*bel*ievable` count as one word rather than three.
    public let startsNewWord: Bool

    public init(range: Range<String.Index>, startsNewWord: Bool) {
        self.range = range
        self.startsNewWord = startsNewWord
    }
}

/// Splits Markdown source into prose runs, skipping markup.
///
/// This is deliberately a lightweight, single-pass scanner rather than a full
/// CommonMark parser. It aims to be *conservative*: when a construct is
/// ambiguous it prefers to treat the characters as prose, because under-counting
/// a writer's words is worse than counting a stray asterisk.
///
/// Skipped constructs:
/// - fenced code blocks (``` and ~~~) and their contents
/// - HTML comments, including multi-line ones
/// - thematic breaks, setext underlines and table separator rows
/// - link reference definitions
/// - leading block markers: ATX heading hashes, blockquote `>`, list bullets,
///   ordered-list numbers and task-list checkboxes
/// - inline code spans
/// - HTML tags and autolinks
/// - image syntax in full, including the alt text
/// - link destinations, keeping the link's visible text
/// - emphasis, strong and strikethrough markers
/// - table cell pipes
///
/// Indented (four-space) code blocks are *not* skipped: manuscripts often use
/// leading indentation for prose, and silently dropping those words would be
/// worse than counting the occasional snippet.
public enum MarkdownProse {

    public static func runs(in text: String) -> [ProseRun] {
        var accumulator = RunAccumulator(text: text)
        var state = BlockState()
        var lineStart = text.startIndex

        while lineStart < text.endIndex {
            let lineEnd = text[lineStart...].firstIndex(of: "\n") ?? text.endIndex
            scanLine(text, lineStart..<lineEnd, state: &state, into: &accumulator)
            accumulator.markBreak()
            lineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
        }

        accumulator.flush()
        return accumulator.runs
    }

    // MARK: - Block level

    private struct BlockState {
        var fence: (marker: Character, length: Int)?
        var inHTMLComment = false
    }

    private static func scanLine(
        _ text: String,
        _ line: Range<String.Index>,
        state: inout BlockState,
        into accumulator: inout RunAccumulator
    ) {
        // An open HTML comment swallows everything until `-->`.
        if state.inHTMLComment {
            guard let close = find(text, "-->", in: line) else { return }
            state.inHTMLComment = false
            scanInlineHandlingComments(
                text,
                close.upperBound..<line.upperBound,
                state: &state,
                into: &accumulator
            )
            return
        }

        var cursor = indentedStart(text, line)

        // Fenced code blocks.
        if let fence = state.fence {
            if isClosingFence(text, cursor..<line.upperBound, marker: fence.marker, length: fence.length) {
                state.fence = nil
            }
            return
        }
        if let opened = openingFence(text, cursor..<line.upperBound) {
            state.fence = opened
            return
        }

        let body = cursor..<line.upperBound
        if isBlank(text, body) { return }
        if isThematicBreakOrSetext(text, body) { return }
        if isTableSeparator(text, body) { return }
        if isLinkReferenceDefinition(text, body) { return }

        cursor = stripBlockMarkers(text, body)
        scanInlineHandlingComments(text, cursor..<line.upperBound, state: &state, into: &accumulator)
    }

    /// Splits a line around HTML comments before inline scanning.
    ///
    /// Comments are handled here rather than in ``scanInline`` because they span
    /// lines, and because their contents may contain `>` characters that the
    /// inline tag handling would otherwise mistake for the end of a tag.
    private static func scanInlineHandlingComments(
        _ text: String,
        _ range: Range<String.Index>,
        state: inout BlockState,
        into accumulator: inout RunAccumulator
    ) {
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            guard let open = find(text, "<!--", in: cursor..<range.upperBound) else {
                scanInline(text, cursor..<range.upperBound, into: &accumulator)
                return
            }
            scanInline(text, cursor..<open.lowerBound, into: &accumulator)
            accumulator.markSyntax()

            guard let close = find(text, "-->", in: open.upperBound..<range.upperBound) else {
                state.inHTMLComment = true
                return
            }
            cursor = close.upperBound
        }
    }

    /// Skips up to three leading spaces (or any tabs), matching Markdown's
    /// tolerance for slight indentation before a block construct.
    private static func indentedStart(_ text: String, _ line: Range<String.Index>) -> String.Index {
        var index = line.lowerBound
        var spaces = 0
        while index < line.upperBound {
            let character = text[index]
            if character == " " && spaces < 3 {
                spaces += 1
            } else if character == "\t" {
                spaces = 0
            } else {
                break
            }
            index = text.index(after: index)
        }
        return index
    }

    private static func isBlank(_ text: String, _ range: Range<String.Index>) -> Bool {
        !text[range].contains { !$0.isWhitespace }
    }

    private static func openingFence(
        _ text: String,
        _ range: Range<String.Index>
    ) -> (marker: Character, length: Int)? {
        guard let first = text[range].first, first == "`" || first == "~" else { return nil }
        let length = text[range].prefix { $0 == first }.count
        guard length >= 3 else { return nil }
        // An opening ``` fence may carry an info string; ~~~ may too.
        return (first, length)
    }

    private static func isClosingFence(
        _ text: String,
        _ range: Range<String.Index>,
        marker: Character,
        length: Int
    ) -> Bool {
        let trimmed = text[range].drop { $0 == " " }
        let run = trimmed.prefix { $0 == marker }
        guard run.count >= length else { return false }
        return trimmed.dropFirst(run.count).allSatisfy { $0.isWhitespace }
    }

    private static func isThematicBreakOrSetext(_ text: String, _ range: Range<String.Index>) -> Bool {
        let trimmed = text[range].filter { !$0.isWhitespace }
        guard let first = trimmed.first else { return false }
        switch first {
        case "-", "*", "_":
            return trimmed.count >= 3 && trimmed.allSatisfy { $0 == first }
        case "=":
            return trimmed.allSatisfy { $0 == "=" }
        default:
            return false
        }
    }

    private static func isTableSeparator(_ text: String, _ range: Range<String.Index>) -> Bool {
        let trimmed = text[range].filter { !$0.isWhitespace }
        guard trimmed.contains("-") else { return false }
        return trimmed.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" }
    }

    /// Matches `[label]: destination`, which carries no prose the writer sees.
    private static func isLinkReferenceDefinition(_ text: String, _ range: Range<String.Index>) -> Bool {
        guard text[range].first == "[" else { return false }
        guard let close = text[range].firstIndex(of: "]") else { return false }
        let after = text.index(after: close)
        return after < range.upperBound && text[after] == ":"
    }

    /// Consumes blockquote markers, list bullets, heading hashes and task
    /// checkboxes, which repeat (`> - [ ] item`).
    private static func stripBlockMarkers(_ text: String, _ range: Range<String.Index>) -> String.Index {
        var index = range.lowerBound
        var changed = true

        while changed && index < range.upperBound {
            changed = false
            index = skipSpaces(text, index, limit: range.upperBound)
            guard index < range.upperBound else { break }

            switch text[index] {
            case ">":
                index = text.index(after: index)
                changed = true

            case "#":
                let hashes = text[index..<range.upperBound].prefix { $0 == "#" }
                if hashes.count <= 6 {
                    let after = text.index(index, offsetBy: hashes.count)
                    if after >= range.upperBound || text[after] == " " || text[after] == "\t" {
                        index = after
                        changed = true
                    }
                }

            case "-", "*", "+":
                let after = text.index(after: index)
                if after < range.upperBound, text[after] == " " || text[after] == "\t" {
                    index = after
                    changed = true
                }

            case "[":
                // Task-list checkbox, only meaningful straight after a bullet.
                if let after = taskCheckboxEnd(text, index, limit: range.upperBound) {
                    index = after
                    changed = true
                }

            case let character where character.isNumber:
                let digits = text[index..<range.upperBound].prefix { $0.isNumber }
                let afterDigits = text.index(index, offsetBy: digits.count)
                if afterDigits < range.upperBound, text[afterDigits] == "." || text[afterDigits] == ")" {
                    let afterDelimiter = text.index(after: afterDigits)
                    if afterDelimiter < range.upperBound,
                       text[afterDelimiter] == " " || text[afterDelimiter] == "\t" {
                        index = afterDelimiter
                        changed = true
                    }
                }

            default:
                break
            }
        }
        return index
    }

    private static func taskCheckboxEnd(
        _ text: String,
        _ index: String.Index,
        limit: String.Index
    ) -> String.Index? {
        let one = text.index(after: index)
        guard one < limit else { return nil }
        let marker = text[one]
        guard marker == " " || marker == "x" || marker == "X" else { return nil }
        let two = text.index(after: one)
        guard two < limit, text[two] == "]" else { return nil }
        return text.index(after: two)
    }

    private static func skipSpaces(_ text: String, _ index: String.Index, limit: String.Index) -> String.Index {
        var index = index
        while index < limit, text[index] == " " || text[index] == "\t" {
            index = text.index(after: index)
        }
        return index
    }

    private static func find(_ text: String, _ needle: String, in range: Range<String.Index>) -> Range<String.Index>? {
        text.range(of: needle, range: range)
    }

    // MARK: - Inline level

    private static func scanInline(
        _ text: String,
        _ range: Range<String.Index>,
        into accumulator: inout RunAccumulator
    ) {
        var index = range.lowerBound

        while index < range.upperBound {
            let character = text[index]
            let next = text.index(after: index)

            switch character {
            case "\\":
                // An escape makes the following character literal prose.
                accumulator.markSyntax()
                if next < range.upperBound {
                    accumulator.prose(from: next, to: text.index(after: next))
                    index = text.index(after: next)
                } else {
                    index = next
                }

            case "`":
                let ticks = text[index..<range.upperBound].prefix { $0 == "`" }
                let fence = String(repeating: "`", count: ticks.count)
                let searchFrom = text.index(index, offsetBy: ticks.count)
                accumulator.markSyntax()
                if searchFrom < range.upperBound,
                   let close = text.range(of: fence, range: searchFrom..<range.upperBound) {
                    index = close.upperBound
                } else {
                    index = searchFrom
                }

            case "<":
                if let close = text[index..<range.upperBound].firstIndex(of: ">") {
                    accumulator.markSyntax()
                    index = text.index(after: close)
                } else {
                    accumulator.prose(from: index, to: next)
                    index = next
                }

            case "!":
                // Image: drop the whole construct, alt text included.
                if next < range.upperBound, text[next] == "[",
                   let close = matchingBracket(text, from: next, limit: range.upperBound) {
                    accumulator.markSyntax()
                    index = skipLinkTail(text, after: close, limit: range.upperBound)
                } else {
                    accumulator.prose(from: index, to: next)
                    index = next
                }

            case "[":
                if let close = matchingBracket(text, from: index, limit: range.upperBound),
                   isLinkTail(text, after: close, limit: range.upperBound) {
                    // Keep the visible link text, drop the destination.
                    accumulator.markSyntax()
                    scanInline(text, next..<close, into: &accumulator)
                    accumulator.markSyntax()
                    index = skipLinkTail(text, after: close, limit: range.upperBound)
                } else {
                    // A bare bracket is prose, and Writing Check should see it.
                    accumulator.prose(from: index, to: next)
                    index = next
                }

            case "*", "_", "~":
                accumulator.markSyntax()
                index = next

            case "|":
                accumulator.markSyntax()
                index = next

            default:
                accumulator.prose(from: index, to: next)
                index = next
            }
        }
    }

    private static func matchingBracket(
        _ text: String,
        from open: String.Index,
        limit: String.Index
    ) -> String.Index? {
        var depth = 0
        var index = open
        while index < limit {
            switch text[index] {
            case "[": depth += 1
            case "]":
                depth -= 1
                if depth == 0 { return index }
            case "\\": index = text.index(after: index)
            default: break
            }
            guard index < limit else { break }
            index = text.index(after: index)
        }
        return nil
    }

    private static func isLinkTail(_ text: String, after close: String.Index, limit: String.Index) -> Bool {
        let after = text.index(after: close)
        guard after < limit else { return false }
        return text[after] == "(" || text[after] == "["
    }

    private static func skipLinkTail(_ text: String, after close: String.Index, limit: String.Index) -> String.Index {
        let after = text.index(after: close)
        guard after < limit else { return after }
        let opener = text[after]
        let closer: Character = opener == "(" ? ")" : "]"
        guard opener == "(" || opener == "[" else { return after }

        // A link destination may itself contain balanced parentheses, as in
        // `https://example.com/a_(b)_c`, so track depth rather than stopping at
        // the first closing character.
        var depth = 1
        var index = text.index(after: after)
        while index < limit {
            let character = text[index]
            if character == "\\" {
                index = text.index(after: index)
            } else if character == opener {
                depth += 1
            } else if character == closer {
                depth -= 1
                if depth == 0 { return text.index(after: index) }
            }
            guard index < limit else { break }
            index = text.index(after: index)
        }
        return limit
    }
}

// MARK: - Accumulator

/// Coalesces adjacent prose characters into runs and records whether whitespace
/// separated one run from the next.
private struct RunAccumulator {
    let text: String
    private(set) var runs: [ProseRun] = []

    private var start: String.Index?
    private var end: String.Index?
    private var breakPending = true

    init(text: String) {
        self.text = text
    }

    mutating func prose(from lower: String.Index, to upper: String.Index) {
        guard lower < upper else { return }
        if let currentEnd = end, currentEnd == lower {
            end = upper
        } else {
            flush()
            start = lower
            end = upper
        }
    }

    /// Skipped markup that contained no whitespace: the surrounding prose still
    /// belongs to a single word.
    mutating func markSyntax() {
        flush()
    }

    /// A line break or skipped whitespace: whatever comes next starts a new word.
    mutating func markBreak() {
        flush()
        breakPending = true
    }

    mutating func flush() {
        if let start, let end {
            runs.append(ProseRun(range: start..<end, startsNewWord: breakPending))
            breakPending = false
        }
        start = nil
        end = nil
    }
}
