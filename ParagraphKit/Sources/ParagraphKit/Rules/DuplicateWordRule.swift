import Foundation

/// Reports a word typed twice in a row, such as `the the`.
///
/// Only genuinely adjacent words are reported: punctuation between them means
/// the repetition is deliberate, so `No, no` and `He ran. Ran hard.` are left
/// alone. A short allow list covers the doubles that are correct English.
public struct DuplicateWordRule: WritingCheckRule {
    public let identifier = "duplicate-word"

    /// Doubles that are grammatical rather than accidental.
    public static let defaultAllowedDoubles: Set<String> = ["had", "that", "no"]

    private let allowedDoubles: Set<String>

    public init(allowedDoubles: Set<String> = DuplicateWordRule.defaultAllowedDoubles) {
        self.allowedDoubles = allowedDoubles
    }

    public func check(_ document: ProseDocument) -> [WritingCheckIssue] {
        var issues: [WritingCheckIssue] = []

        for (offset, word) in document.words.enumerated() where offset > 0 {
            let previous = document.words[offset - 1]

            guard word.followsWhitespaceOnly,
                  word.paragraph == previous.paragraph,
                  word.folded == previous.folded,
                  !allowedDoubles.contains(word.folded),
                  // Numbers repeat legitimately in lists and tables.
                  word.folded.contains(where: { $0.isLetter })
            else { continue }

            issues.append(
                WritingCheckIssue(
                    ruleIdentifier: identifier,
                    severity: .warning,
                    finding: .duplicateWord(word.text),
                    range: previous.range.lowerBound..<word.range.upperBound,
                    line: document.lineNumber(at: previous.range.lowerBound)
                )
            )
        }
        return issues
    }
}
