import Testing
@testable import ParagraphKit

@Suite("Word counting")
struct WordCounterTests {

    private func count(_ markdown: String) -> Int {
        WordCounter.count(markdown: markdown)
    }

    // MARK: - Plain prose

    @Test("Counts words in plain prose")
    func plainProse() {
        #expect(count("The lamp guttered and went out.") == 6)
    }

    @Test("An empty document has no words")
    func empty() {
        #expect(count("") == 0)
        #expect(count("   \n\n\t  ") == 0)
    }

    @Test("Repeated whitespace does not inflate the count")
    func whitespace() {
        #expect(count("one   two\n\n\nthree\tfour") == 4)
    }

    // MARK: - Markdown structure

    @Test("Heading markers are not words")
    func headings() {
        #expect(count("# Chapter One") == 2)
        #expect(count("### A Smaller Heading") == 3)
        #expect(count("Title\n=====") == 1)
    }

    @Test("List bullets and numbers are not words")
    func lists() {
        #expect(count("- milk\n- bread\n- salt") == 3)
        #expect(count("1. first\n2. second") == 2)
        #expect(count("- [ ] pack the case") == 3)
    }

    @Test("Blockquote markers are not words")
    func blockquotes() {
        #expect(count("> She never wrote back.") == 4)
        #expect(count("> > nested quote") == 2)
    }

    @Test("Thematic breaks contribute nothing")
    func thematicBreaks() {
        #expect(count("one\n\n---\n\ntwo") == 2)
        #expect(count("one\n\n***\n\ntwo") == 2)
    }

    @Test("Emphasis markers are not words")
    func emphasis() {
        #expect(count("She was *quite* certain.") == 4)
        #expect(count("He was **never** told.") == 4)
        #expect(count("~~struck~~ through") == 2)
    }

    @Test("Emphasis inside a word does not split the word")
    func intraWordEmphasis() {
        #expect(count("un*bel*ievable") == 1)
    }

    @Test("Link text counts, the destination does not")
    func links() {
        #expect(count("See [the letter](https://example.com/letter) again.") == 4)
        #expect(count("See [the letter][ref] again.") == 4)
        #expect(count("[label]: https://example.com/thing") == 0)
    }

    @Test("Images contribute nothing, alt text included")
    func images() {
        #expect(count("Before ![a photograph of the pier](pier.jpg) after.") == 2)
    }

    @Test("Code spans and fenced blocks are not prose")
    func code() {
        #expect(count("Run `swift build` now.") == 2)
        #expect(count("Before\n\n```\nlet x = 1\nprint(x)\n```\n\nAfter") == 2)
        #expect(count("Before\n\n~~~swift\nlet x = 1\n~~~\n\nAfter") == 2)
    }

    @Test("Unterminated fences swallow the rest of the document")
    func unterminatedFence() {
        #expect(count("Before\n\n```\nlet x = 1") == 1)
    }

    @Test("HTML comments and tags are not prose")
    func html() {
        #expect(count("Visible <!-- hidden note --> again") == 2)
        #expect(count("Visible <!--\nspanning\nlines\n--> again") == 2)
        #expect(count("A <em>tagged</em> word") == 3)
    }

    @Test("Table pipes and separator rows are not words")
    func tables() {
        let table = """
        | Name | Role |
        | --- | --- |
        | Ada | engineer |
        """
        #expect(count(table) == 4)   // Name, Role, Ada, engineer
    }

    @Test("Indented prose is still counted")
    func indentedProseIsProse() {
        // Four-space indentation is Markdown code, but in a manuscript it is far
        // more likely to be intentional prose indentation.
        #expect(count("    She waited by the door.") == 5)
    }

    // MARK: - Word shape

    @Test("Contractions count as one word")
    func contractions() {
        #expect(count("don't") == 1)
        #expect(count("don\u{2019}t") == 1)
        #expect(count("o\u{2019}clock") == 1)
    }

    @Test("Hyphenated words count as one word")
    func hyphenated() {
        #expect(count("well-known") == 1)
        #expect(count("mother-in-law") == 1)
    }

    @Test("Numbers, decimals and abbreviations count as one word")
    func numerals() {
        #expect(count("3.14") == 1)
        #expect(count("1,000") == 1)
        #expect(count("U.S.A.") == 1)
        #expect(count("She counted 42 birds.") == 4)
    }

    @Test("Dashes and ellipses separate words")
    func separators() {
        #expect(count("dawn\u{2014}light") == 2)
        #expect(count("wait\u{2026}listen") == 2)
        #expect(count("either/or") == 2)
    }

    @Test("Trailing punctuation does not create extra words")
    func trailingPunctuation() {
        #expect(count("Stop. Wait, listen!") == 3)
        #expect(count("\u{201C}Hello,\u{201D} she said.") == 3)
    }

    @Test("Unicode prose is counted")
    func unicode() {
        #expect(count("Se\u{00F1}ora Garc\u{00ED}a lleg\u{00F3} tarde") == 4)
        #expect(count("\u{4ECA}\u{65E5} is a word") == 4)
    }

    @Test("A realistic manuscript page counts as expected")
    func manuscript() {
        let markdown = """
        # Chapter Two

        The rain had not stopped since Tuesday. She set the *lamp* on the sill and
        watched the water climb the step, one slow inch at a time.

        > It will pass, her mother had said.

        - Fetch the sandbags
        - Telephone the yard

        She did neither.
        """
        // heading 2, body 27, quote 7, two bullets 3 + 3, closing line 3
        #expect(count(markdown) == 45)
    }
}
