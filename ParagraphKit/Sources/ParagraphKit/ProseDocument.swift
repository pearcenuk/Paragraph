import Foundation

/// A single word taken from the prose of a Markdown document.
public struct ProseWord: Equatable, Sendable {
    public let text: String
    public let folded: String
    public let range: Range<String.Index>
    /// Index into ``ProseDocument/paragraphs`` that this word belongs to.
    public let paragraph: Int
    /// `true` when nothing but whitespace and markup separated this word from
    /// the previous one, so no punctuation or sentence boundary intervened.
    public let followsWhitespaceOnly: Bool

    public init(
        text: String,
        folded: String,
        range: Range<String.Index>,
        paragraph: Int,
        followsWhitespaceOnly: Bool
    ) {
        self.text = text
        self.folded = folded
        self.range = range
        self.paragraph = paragraph
        self.followsWhitespaceOnly = followsWhitespaceOnly
    }
}

/// The parsed view of a document that every Writing Check rule works from.
///
/// Parsing happens once per run, so adding a rule costs a pass over
/// pre-computed words rather than another scan of the source.
public struct ProseDocument: Sendable {
    public let text: String
    public let runs: [ProseRun]
    public let words: [ProseWord]

    /// Paragraph ranges over the *original* text, split on line breaks. In a
    /// Markdown source editor one typed line is one paragraph, which is also the
    /// unit Focus Mode highlights.
    public let paragraphs: [Range<String.Index>]

    private let lineStarts: [String.Index]
    private let runsByParagraph: [[ProseRun]]

    public init(text: String) {
        self.text = text
        self.runs = MarkdownProse.runs(in: text)
        let paragraphs = Self.paragraphRanges(in: text)
        self.paragraphs = paragraphs
        self.lineStarts = paragraphs.map(\.lowerBound)
        self.runsByParagraph = Self.groupRuns(runs, by: paragraphs)
        self.words = Self.tokenise(text: text, runs: runs, paragraphs: paragraphs)
    }

    /// One-based line number, found by binary search over precomputed line starts.
    public func lineNumber(at index: String.Index) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        var result = 0
        while low <= high {
            let middle = (low + high) / 2
            if lineStarts[middle] <= index {
                result = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return result + 1
    }

    /// Prose runs that begin inside the paragraph at `number`.
    ///
    /// Grouped once during parsing so that a rule looping over paragraphs stays
    /// linear in the size of the document rather than quadratic.
    public func runs(inParagraph number: Int) -> [ProseRun] {
        guard runsByParagraph.indices.contains(number) else { return [] }
        return runsByParagraph[number]
    }

    private static func groupRuns(
        _ runs: [ProseRun],
        by paragraphs: [Range<String.Index>]
    ) -> [[ProseRun]] {
        var grouped = [[ProseRun]](repeating: [], count: paragraphs.count)
        var paragraph = 0
        for run in runs {
            while paragraph + 1 < paragraphs.count,
                  run.range.lowerBound >= paragraphs[paragraph].upperBound {
                paragraph += 1
            }
            grouped[paragraph].append(run)
        }
        return grouped
    }

    // MARK: - Building

    private static func paragraphRanges(in text: String) -> [Range<String.Index>] {
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
        ranges.append(start..<text.endIndex)
        return ranges
    }

    private static func tokenise(
        text: String,
        runs: [ProseRun],
        paragraphs: [Range<String.Index>]
    ) -> [ProseWord] {
        var words: [ProseWord] = []
        var paragraphIndex = 0

        var wordStart: String.Index?
        var wordEnd: String.Index?

        /// Punctuation seen since the last emitted word. Markup skipped between
        /// prose runs deliberately does not set this: `*the* the` is still a
        /// duplicate the writer wants to know about.
        var punctuationSinceWord = false
        var followsWhitespaceOnly = true

        func advanceParagraph(to index: String.Index) {
            while paragraphIndex + 1 < paragraphs.count,
                  index >= paragraphs[paragraphIndex].upperBound {
                paragraphIndex += 1
            }
        }

        func finish() {
            guard let start = wordStart, var end = wordEnd else { return }
            wordStart = nil
            wordEnd = nil

            // Drop connectors that ended up trailing, as in `dawn,` or `so...`
            // A trimmed connector *was* punctuation, so it must still break the
            // adjacency of the next word: `He ran. Ran hard.` is not a duplicate.
            var trailingPunctuation = false
            while end > start, WordCounter.isConnector(text[text.index(before: end)]) {
                end = text.index(before: end)
                trailingPunctuation = true
            }
            defer { punctuationSinceWord = trailingPunctuation }
            guard start < end else { return }

            advanceParagraph(to: start)
            let slice = String(text[start..<end])
            words.append(
                ProseWord(
                    text: slice,
                    folded: slice.lowercased(),
                    range: start..<end,
                    paragraph: paragraphIndex,
                    followsWhitespaceOnly: followsWhitespaceOnly
                )
            )
        }

        for run in runs {
            if run.startsNewWord { finish() }

            var index = run.range.lowerBound
            while index < run.range.upperBound {
                let character = text[index]
                let next = text.index(after: index)

                if WordCounter.isWordCharacter(character) {
                    if wordStart == nil {
                        followsWhitespaceOnly = !punctuationSinceWord
                        wordStart = index
                    }
                    wordEnd = next
                } else if WordCounter.isConnector(character), wordStart != nil {
                    wordEnd = next
                } else {
                    finish()
                    if !character.isWhitespace { punctuationSinceWord = true }
                }
                index = next
            }
        }
        finish()
        return words
    }
}
