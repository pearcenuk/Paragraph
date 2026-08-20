import Foundation

/// How seriously Paragraph takes a Writing Check result.
///
/// Severity describes a *mechanical* property of the text. It never expresses a
/// judgement about the quality of the writing.
public enum WritingCheckSeverity: String, Sendable, CaseIterable, Comparable {
    /// Almost certainly a mistake: something was opened and never closed.
    case error
    /// Worth a look, but legitimate prose can look like this.
    case warning

    public static func < (lhs: WritingCheckSeverity, rhs: WritingCheckSeverity) -> Bool {
        lhs == .error && rhs == .warning
    }
}

/// What a rule found, described structurally so that the user-facing wording
/// lives in the app's localisation catalogue rather than in the rule.
public enum WritingCheckFinding: Equatable, Sendable {
    case unmatchedOpeningQuote(String)
    case unmatchedClosingQuote(String)
    case unmatchedOpeningDelimiter(String)
    case unmatchedClosingDelimiter(String)
    case duplicateWord(String)
    case repeatedPhrase(String)
}

public struct WritingCheckIssue: Equatable, Sendable {
    public let ruleIdentifier: String
    public let severity: WritingCheckSeverity
    public let finding: WritingCheckFinding
    /// Range in the original document text, ready to be selected in the editor.
    public let range: Range<String.Index>
    /// One-based line number, shown so severity is never signalled by colour alone.
    public let line: Int

    public init(
        ruleIdentifier: String,
        severity: WritingCheckSeverity,
        finding: WritingCheckFinding,
        range: Range<String.Index>,
        line: Int
    ) {
        self.ruleIdentifier = ruleIdentifier
        self.severity = severity
        self.finding = finding
        self.range = range
        self.line = line
    }
}

/// A single mechanical check.
///
/// The protocol is deliberately small: a rule reads a parsed document and
/// returns issues. There is no registration, discovery or plugin mechanism.
public protocol WritingCheckRule: Sendable {
    var identifier: String { get }
    func check(_ document: ProseDocument) -> [WritingCheckIssue]
}

/// Runs the V1 rule set over a document.
public struct WritingCheck: Sendable {
    public let rules: [any WritingCheckRule]

    public static let defaultRules: [any WritingCheckRule] = [
        UnmatchedQuotesRule(),
        UnmatchedDelimitersRule(),
        DuplicateWordRule(),
        RepeatedPhraseRule()
    ]

    public init(rules: [any WritingCheckRule] = WritingCheck.defaultRules) {
        self.rules = rules
    }

    public func run(on text: String) -> [WritingCheckIssue] {
        run(on: ProseDocument(text: text))
    }

    public func run(on document: ProseDocument) -> [WritingCheckIssue] {
        rules
            .flatMap { $0.check(document) }
            .sorted { lhs, rhs in
                if lhs.range.lowerBound != rhs.range.lowerBound {
                    return lhs.range.lowerBound < rhs.range.lowerBound
                }
                return lhs.severity < rhs.severity
            }
    }
}
