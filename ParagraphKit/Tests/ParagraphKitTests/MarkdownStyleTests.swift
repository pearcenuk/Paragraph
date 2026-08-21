import Testing
@testable import ParagraphKit

/// The failure that matters here is a false positive: emphasis applied where
/// the writer did not ask for it. A missed italic is a shrug; half a paragraph
/// unexpectedly bold is a bug you notice every day.
@Suite("Markdown styling")
struct MarkdownStyleTests {

    private func styled(_ text: String, _ kind: MarkdownStyleKind) -> [String] {
        MarkdownStyleScanner.spans(in: text)
            .filter { $0.kind == kind }
            .map { String(text[$0.range]) }
    }

    private func markers(_ text: String) -> [String] {
        styled(text, .marker)
    }

    // MARK: - The basics

    @Test("Emphasis and its markers are both found")
    func emphasis() {
        #expect(styled("She was *quite* certain.", .emphasis) == ["quite"])
        #expect(markers("She was *quite* certain.") == ["*", "*"])
    }

    @Test("Strong emphasis")
    func strong() {
        #expect(styled("He was **never** told.", .strong) == ["never"])
        #expect(markers("He was **never** told.") == ["**", "**"])
    }

    @Test("Both together")
    func strongEmphasis() {
        #expect(styled("It was ***everything***.", .strongEmphasis) == ["everything"])
    }

    @Test("Underscores work like asterisks")
    func underscores() {
        #expect(styled("She was _quite_ certain.", .emphasis) == ["quite"])
        #expect(styled("He was __never__ told.", .strong) == ["never"])
    }

    @Test("Strikethrough")
    func strikethrough() {
        #expect(styled("~~struck~~ through", .strikethrough) == ["struck"])
    }

    @Test("Inline code")
    func code() {
        #expect(styled("Run `swift build` now.", .code) == ["swift build"])
    }

    @Test("Headings are styled, hashes stay as markers")
    func headings() {
        let text = "## Chapter Two"
        #expect(styled(text, .heading(level: 2)) == ["Chapter Two"])
        #expect(markers(text) == ["## "])
    }

    @Test("Emphasis inside a heading still applies")
    func emphasisInHeading() {
        #expect(styled("# A *quiet* chapter", .emphasis) == ["quiet"])
    }

    @Test("Blockquote arrows and list bullets are markers")
    func blockMarkers() {
        #expect(markers("> She never wrote back.") == ["> "])
        #expect(markers("- milk") == ["- "])
        #expect(markers("1. first") == ["1. "])
    }

    // MARK: - The false positives that would be intolerable

    @Test("snake_case is not italic")
    func snakeCase() {
        #expect(styled("The file_name_here value", .emphasis).isEmpty)
        #expect(styled("call some_function(x)", .emphasis).isEmpty)
    }

    @Test("Arithmetic is not emphasis")
    func arithmetic() {
        #expect(styled("2 * 3 * 4 = 24", .emphasis).isEmpty)
        #expect(styled("a * b", .emphasis).isEmpty)
    }

    @Test("A lone marker does not start emphasis that never ends")
    func unclosed() {
        #expect(styled("She was *quite certain.", .emphasis).isEmpty)
        #expect(styled("Five ** stars", .strong).isEmpty)
    }

    @Test("Escaped markers are literal")
    func escaped() {
        #expect(styled("A literal \\*asterisk\\* here", .emphasis).isEmpty)
    }

    @Test("Emphasis does not swallow the rest of the paragraph")
    func bounded() {
        let text = "One *two* three *four* five"
        #expect(styled(text, .emphasis) == ["two", "four"])
    }

    @Test("Nothing inside a fenced code block is emphasised")
    func fencedCode() {
        let text = "Before\n\n```\nlet a = b * c * d\nsnake_case_name\n```\n\nAfter"
        #expect(styled(text, .emphasis).isEmpty)
        #expect(styled(text, .strong).isEmpty)
    }

    @Test("Nothing inside a code span is emphasised")
    func codeSpan() {
        #expect(styled("Type `a * b * c` exactly", .emphasis).isEmpty)
    }

    @Test("A possessive apostrophe is not a delimiter")
    func apostrophes() {
        #expect(styled("the boys' coats and Thomas' idea", .emphasis).isEmpty)
    }

    @Test("Mid-word asterisks still emphasise, as Markdown says they do")
    func intraWordAsterisk() {
        #expect(styled("un*bel*ievable", .emphasis) == ["bel"])
    }

    @Test("An empty pair is not emphasis")
    func empty() {
        #expect(styled("nothing ** here", .strong).isEmpty)
        #expect(styled("nothing ____ here", .strong).isEmpty)
    }

    @Test("Spans never overlap and always sit inside the text")
    func wellFormed() {
        let text = """
        # Chapter *One*

        The **lamp** had been burning, and `code` too, plus ~~this~~.

        > A _quoted_ line.

        - a **list** item
        """
        let spans = MarkdownStyleScanner.spans(in: text)
        for span in spans {
            #expect(span.range.lowerBound >= text.startIndex)
            #expect(span.range.upperBound <= text.endIndex)
        }
        // Spans may nest — a heading contains the emphasis inside it — but they
        // must never partially overlap, which would make the styling ambiguous.
        let emphasised = spans.filter { $0.kind != .marker && $0.kind != .code }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
        for (a, b) in zip(emphasised, emphasised.dropFirst()) {
            let disjoint = a.range.upperBound <= b.range.lowerBound
            let nested = b.range.upperBound <= a.range.upperBound
            #expect(disjoint || nested,
                    "spans partially overlap: \(text[a.range]) / \(text[b.range])")
        }
    }

    @Test("A realistic manuscript page styles as expected")
    func manuscript() {
        let text = "She had *not* expected the **north field** to be drained again."
        #expect(styled(text, .emphasis) == ["not"])
        #expect(styled(text, .strong) == ["north field"])
        #expect(markers(text) == ["*", "*", "**", "**"])
    }
}
