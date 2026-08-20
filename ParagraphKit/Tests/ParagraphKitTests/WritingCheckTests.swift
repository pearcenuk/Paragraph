import Testing
@testable import ParagraphKit

private let leftDouble = "\u{201C}"
private let rightDouble = "\u{201D}"
private let leftSingle = "\u{2018}"
private let rightSingle = "\u{2019}"

private func findings(_ text: String, rules: [any WritingCheckRule]) -> [WritingCheckFinding] {
    WritingCheck(rules: rules).run(on: text).map(\.finding)
}

// MARK: - Quotes

@Suite("Writing Check: unmatched quotation marks")
struct UnmatchedQuotesRuleTests {

    private func check(_ text: String) -> [WritingCheckFinding] {
        findings(text, rules: [UnmatchedQuotesRule()])
    }

    @Test("Balanced typographic quotes are silent")
    func balancedTypographic() {
        #expect(check("\(leftDouble)Come inside,\(rightDouble) she said.").isEmpty)
    }

    @Test("Balanced straight quotes are silent")
    func balancedStraight() {
        #expect(check("\"Come inside,\" she said.").isEmpty)
    }

    @Test("An unclosed typographic quote is an error")
    func unclosedTypographic() {
        #expect(check("\(leftDouble)Come inside, she said.") == [.unmatchedOpeningQuote(leftDouble)])
    }

    @Test("An unclosed straight quote is an error")
    func unclosedStraight() {
        #expect(check("\"Come inside, she said.") == [.unmatchedOpeningQuote("\"")])
    }

    @Test("A closing quote with nothing open is an error")
    func strayClosing() {
        #expect(check("Come inside,\(rightDouble) she said.") == [.unmatchedClosingQuote(rightDouble)])
    }

    @Test("Apostrophes in contractions are not quotes")
    func contractions() {
        #expect(check("She didn\(rightSingle)t answer, and he couldn\(rightSingle)t either.").isEmpty)
        #expect(check("She didn't answer, and he couldn't either.").isEmpty)
        #expect(check("It was six o\(rightSingle)clock.").isEmpty)
    }

    @Test("Possessive apostrophes are not quotes")
    func possessives() {
        #expect(check("The boys\(rightSingle) coats were wet.").isEmpty)
        #expect(check("The boys' coats were wet.").isEmpty)
        #expect(check("That was Thomas\(rightSingle) idea.").isEmpty)
    }

    @Test("Balanced single quotes are silent, even containing a contraction")
    func balancedSingleWithContraction() {
        #expect(check("\(leftSingle)She didn\(rightSingle)t answer,\(rightSingle) he wrote.").isEmpty)
    }

    @Test("An unclosed typographic single quote is an error")
    func unclosedSingle() {
        #expect(check("\(leftSingle)She never came back.") == [.unmatchedOpeningQuote(leftSingle)])
    }

    @Test("Straight single quotes are never reported")
    func straightSinglesIgnored() {
        // Genuinely ambiguous with apostrophes; a false error is worse.
        #expect(check("'twas the night, and the cat's paw.").isEmpty)
    }

    @Test("Multi-paragraph dialogue is not reported")
    func multiParagraphDialogue() {
        let text = """
        \(leftDouble)It began on the Tuesday, and it did not stop.

        \(leftDouble)By Friday the road was gone,\(rightDouble) she said.
        """
        #expect(check(text).isEmpty)
    }

    @Test("The last paragraph of continued dialogue must still close")
    func unterminatedDialogue() {
        let text = """
        \(leftDouble)It began on the Tuesday.

        \(leftDouble)By Friday the road was gone.
        """
        #expect(check(text) == [.unmatchedOpeningQuote(leftDouble)])
    }

    @Test("Quotes inside code are ignored")
    func codeIsIgnored() {
        #expect(check("Run `printf \"hello` to test.").isEmpty)
        #expect(check("Before\n\n```\nlet s = \"unclosed\n```\n\nAfter").isEmpty)
    }

    @Test("Each paragraph is balanced independently")
    func perParagraph() {
        let text = """
        \(leftDouble)One.\(rightDouble)

        Two\(rightDouble)
        """
        #expect(check(text) == [.unmatchedClosingQuote(rightDouble)])
    }

    @Test("Nested single quotes inside double quotes are silent")
    func nested() {
        let text = "\(leftDouble)She said \(leftSingle)no\(rightSingle) twice,\(rightDouble) he wrote."
        #expect(check(text).isEmpty)
    }
}

// MARK: - Delimiters

@Suite("Writing Check: unmatched parentheses and brackets")
struct UnmatchedDelimitersRuleTests {

    private func check(_ text: String) -> [WritingCheckFinding] {
        findings(text, rules: [UnmatchedDelimitersRule()])
    }

    @Test("Balanced delimiters are silent")
    func balanced() {
        #expect(check("She waited (as always) by the door.").isEmpty)
        #expect(check("A note [in brackets] here.").isEmpty)
        #expect(check("Nested (one (two) three) here.").isEmpty)
    }

    @Test("An unclosed parenthesis is an error")
    func unclosedParenthesis() {
        #expect(check("She waited (as always by the door.") == [.unmatchedOpeningDelimiter("(")])
    }

    @Test("A stray closing parenthesis is an error")
    func strayClosingParenthesis() {
        #expect(check("She waited as always) by the door.") == [.unmatchedClosingDelimiter(")")])
    }

    @Test("An unclosed square bracket is an error")
    func unclosedBracket() {
        #expect(check("A note [in brackets here.") == [.unmatchedOpeningDelimiter("[")])
    }

    @Test("Markdown links do not look like unmatched brackets")
    func linksAreNotBrackets() {
        #expect(check("See [the letter](https://example.com/a_(b)_c) again.").isEmpty)
        #expect(check("See ![a photo](pier.jpg) again.").isEmpty)
        #expect(check("See [the letter][ref] again.").isEmpty)
    }

    @Test("Delimiters inside code are ignored")
    func codeIsIgnored() {
        #expect(check("Call `foo(bar` here.").isEmpty)
    }

    @Test("Each paragraph is balanced independently")
    func perParagraph() {
        let text = """
        She waited (as always

        by the door.)
        """
        let result = check(text)
        #expect(result.count == 2)
        #expect(result.contains(.unmatchedOpeningDelimiter("(")))
        #expect(result.contains(.unmatchedClosingDelimiter(")")))
    }

    @Test("Escaped brackets are treated as prose")
    func escaped() {
        #expect(check("A literal \\[bracket\\] pair.").isEmpty)
    }
}

// MARK: - Duplicate words

@Suite("Writing Check: consecutive duplicate words")
struct DuplicateWordRuleTests {

    private func check(_ text: String) -> [WritingCheckFinding] {
        findings(text, rules: [DuplicateWordRule()])
    }

    @Test("A repeated word is a warning")
    func repeated() {
        #expect(check("She left the the house.") == [.duplicateWord("the")])
    }

    @Test("Repetition is matched regardless of case")
    func caseInsensitive() {
        #expect(check("The The house stood empty.") == [.duplicateWord("The")])
    }

    @Test("Ordinary prose is silent")
    func negative() {
        #expect(check("She left the house and did not look back.").isEmpty)
    }

    @Test("Punctuation between the words means it is deliberate")
    func punctuationSeparated() {
        #expect(check("No, no, she said.").isEmpty)
        #expect(check("He ran. Ran until his chest burned.").isEmpty)
    }

    @Test("Grammatical doubles are allowed")
    func allowedDoubles() {
        #expect(check("She had had enough.").isEmpty)
        #expect(check("He knew that that was wrong.").isEmpty)
    }

    @Test("A duplicate across a line break is still a duplicate")
    func acrossLineBreak() {
        // Wrapped manuscript lines are where this typo hides best.
        #expect(check("She left the\nthe house.").isEmpty)
    }

    @Test("A duplicate split by emphasis is still reported")
    func acrossEmphasis() {
        #expect(check("She left the *the* house.") == [.duplicateWord("the")])
    }

    @Test("Repeated numbers are not reported")
    func numbers() {
        #expect(check("Rows 2 2 were blank.").isEmpty)
    }

    @Test("Duplicates inside code are ignored")
    func codeIsIgnored() {
        #expect(check("Type `the the` exactly.").isEmpty)
    }
}

// MARK: - Repeated phrases

@Suite("Writing Check: repeated nearby phrases")
struct RepeatedPhraseRuleTests {

    private func check(_ text: String, window: Int = 50) -> [WritingCheckFinding] {
        findings(text, rules: [RepeatedPhraseRule(windowInWords: window)])
    }

    @Test("A phrase repeated close by is a warning")
    func nearbyRepeat() {
        let text = "She opened the wooden door and stepped through. "
            + "Behind her the wind rose. She opened the wooden door again."
        #expect(check(text) == [.repeatedPhrase("She opened the wooden door")])
    }

    @Test("A phrase repeated far away is silent")
    func distantRepeat() {
        let filler = String(repeating: "word ", count: 60)
        let text = "She opened the wooden door. " + filler + "She opened the wooden door."
        #expect(check(text).isEmpty)
    }

    @Test("Ordinary prose is silent")
    func negative() {
        #expect(check("She crossed the yard and unlatched the gate behind the barn.").isEmpty)
    }

    @Test("Phrases made only of function words are ignored")
    func stopWordsOnly() {
        #expect(check("It was in the house, and it was in the garden too.").isEmpty)
    }

    @Test("An overlapping run of one word is not a repeat")
    func overlapping() {
        #expect(check("very very very very").isEmpty)
    }

    @Test("A short document cannot repeat")
    func tooShort() {
        #expect(check("Only four words here").isEmpty)
    }
}

// MARK: - Engine

@Suite("Writing Check engine")
struct WritingCheckEngineTests {

    @Test("Clean prose produces no issues")
    func cleanProse() {
        let text = "\(leftDouble)Come inside,\(rightDouble) she said. The door closed behind them."
        #expect(WritingCheck().run(on: text).isEmpty)
    }

    @Test("Issues are ordered by position, errors before warnings")
    func ordering() {
        let text = "She left the the house (and never returned."
        let issues = WritingCheck().run(on: text)
        #expect(issues.count == 2)
        #expect(issues[0].finding == .duplicateWord("the"))
        #expect(issues[1].finding == .unmatchedOpeningDelimiter("("))
        #expect(issues.map(\.range.lowerBound).sorted() == issues.map(\.range.lowerBound))
    }

    @Test("Severities are assigned per rule")
    func severities() {
        let text = "She left the the house (and never returned."
        let issues = WritingCheck().run(on: text)
        #expect(issues.first { $0.ruleIdentifier == "duplicate-word" }?.severity == .warning)
        #expect(issues.first { $0.ruleIdentifier == "unmatched-delimiters" }?.severity == .error)
    }

    @Test("Line numbers are one-based and correct")
    func lineNumbers() {
        let text = "First line is fine.\n\nShe left the the house."
        let issues = WritingCheck().run(on: text)
        #expect(issues.count == 1)
        #expect(issues[0].line == 3)
    }

    @Test("Reported ranges select the offending text")
    func ranges() {
        let text = "She left the the house."
        let issue = try! #require(WritingCheck().run(on: text).first)
        #expect(String(text[issue.range]) == "the the")
    }

    @Test("An empty document produces no issues")
    func empty() {
        #expect(WritingCheck().run(on: "").isEmpty)
    }
}
