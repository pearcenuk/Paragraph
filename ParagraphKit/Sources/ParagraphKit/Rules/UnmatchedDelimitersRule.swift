import Foundation

/// Reports parentheses and square brackets that were opened and never closed,
/// or closed without being opened.
///
/// Matching is scoped to a paragraph, because a bracket left open at the end of
/// a paragraph is almost always a slip rather than a deliberate construction.
///
/// Markdown link and image syntax never reaches this rule: ``MarkdownProse``
/// has already consumed those brackets, so `[label](url)` is silent while a
/// bare `[aside` is reported.
public struct UnmatchedDelimitersRule: WritingCheckRule {
    public let identifier = "unmatched-delimiters"

    public init() {}

    private struct Pair {
        let open: Character
        let close: Character
    }

    private let pairs = [
        Pair(open: "(", close: ")"),
        Pair(open: "[", close: "]")
    ]

    public func check(_ document: ProseDocument) -> [WritingCheckIssue] {
        let text = document.text
        var issues: [WritingCheckIssue] = []

        for number in document.paragraphs.indices {
            var stacks: [Character: [String.Index]] = [:]
            let runs = document.runs(inParagraph: number)

            for run in runs {
                var index = run.range.lowerBound
                while index < run.range.upperBound {
                    let character = text[index]

                    if let pair = pairs.first(where: { $0.open == character }) {
                        stacks[pair.open, default: []].append(index)
                    } else if let pair = pairs.first(where: { $0.close == character }) {
                        if stacks[pair.open]?.isEmpty == false {
                            stacks[pair.open]?.removeLast()
                        } else {
                            issues.append(
                                issue(
                                    .unmatchedClosingDelimiter(String(pair.close)),
                                    at: index,
                                    in: document
                                )
                            )
                        }
                    }
                    index = text.index(after: index)
                }
            }

            for pair in pairs {
                for open in stacks[pair.open] ?? [] {
                    issues.append(
                        issue(.unmatchedOpeningDelimiter(String(pair.open)), at: open, in: document)
                    )
                }
            }
        }

        return issues.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private func issue(
        _ finding: WritingCheckFinding,
        at index: String.Index,
        in document: ProseDocument
    ) -> WritingCheckIssue {
        WritingCheckIssue(
            ruleIdentifier: identifier,
            severity: .error,
            finding: finding,
            range: index..<document.text.index(after: index),
            line: document.lineNumber(at: index)
        )
    }
}
