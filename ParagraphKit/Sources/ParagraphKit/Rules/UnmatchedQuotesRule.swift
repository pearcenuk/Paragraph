import Foundation

/// Reports quotation marks that were opened and never closed, or closed without
/// being opened.
///
/// The rule is built around the ways real manuscripts use apostrophes:
///
/// - `’` between two letters is always an apostrophe (`don’t`, `o’clock`).
/// - `’` after a letter is treated as a closing single quote only when a `‘` is
///   actually open, so `the boys’ toys` is left alone in ordinary prose.
/// - Straight `'` is never reported. It is genuinely ambiguous between an
///   apostrophe and a quote, and a false error in a manuscript is worse than a
///   missed one.
/// - Multi-paragraph dialogue, where each paragraph re-opens the quote and only
///   the last one closes it, is recognised and not reported.
///
/// Code spans and fenced code blocks are skipped, because ``ProseDocument``
/// hands the rule prose runs only.
public struct UnmatchedQuotesRule: WritingCheckRule {
    public let identifier = "unmatched-quotes"

    public init() {}

    private struct Pending {
        let index: String.Index
        let mark: String
    }

    public func check(_ document: ProseDocument) -> [WritingCheckIssue] {
        let text = document.text
        var issues: [WritingCheckIssue] = []
        var pendingOpen = [Pending?](repeating: nil, count: document.paragraphs.count)

        for number in document.paragraphs.indices {
            var straightOpen: Pending?
            var curlyDouble: [Pending] = []
            var curlySingle: [Pending] = []

            for run in document.runs(inParagraph: number) {
                var index = run.range.lowerBound
                while index < run.range.upperBound {
                    switch text[index] {
                    case "\"":
                        straightOpen = straightOpen == nil
                            ? Pending(index: index, mark: "\"")
                            : nil

                    case "\u{201C}":                                  // “
                        curlyDouble.append(Pending(index: index, mark: "\u{201C}"))

                    case "\u{201D}":                                  // ”
                        if curlyDouble.isEmpty {
                            issues.append(
                                issue(.unmatchedClosingQuote("\u{201D}"), at: index, in: document)
                            )
                        } else {
                            curlyDouble.removeLast()
                        }

                    case "\u{2018}":                                  // ‘
                        curlySingle.append(Pending(index: index, mark: "\u{2018}"))

                    case "\u{2019}":                                  // ’
                        if !isApostrophe(at: index, in: text), !curlySingle.isEmpty {
                            curlySingle.removeLast()
                        }

                    default:
                        break
                    }
                    index = text.index(after: index)
                }
            }

            // A single quote left open is reported; a stray `’` never is.
            for open in curlySingle {
                issues.append(issue(.unmatchedOpeningQuote(open.mark), at: open.index, in: document))
            }
            pendingOpen[number] = curlyDouble.first ?? straightOpen
        }

        for (number, pending) in pendingOpen.enumerated() {
            guard let pending else { continue }
            if continuesInNextParagraph(after: number, in: document, mark: pending.mark) { continue }
            issues.append(issue(.unmatchedOpeningQuote(pending.mark), at: pending.index, in: document))
        }

        return issues.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// `’` sitting between two letters is part of a word, never a quote.
    private func isApostrophe(at index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return false }
        let before = text[text.index(before: index)]
        let afterIndex = text.index(after: index)
        guard afterIndex < text.endIndex else { return false }
        return before.isLetter && text[afterIndex].isLetter
    }

    /// Fiction re-opens the quotation mark on every paragraph of a continued
    /// speech and closes it only at the end. Recognise that shape.
    private func continuesInNextParagraph(
        after number: Int,
        in document: ProseDocument,
        mark: String
    ) -> Bool {
        let text = document.text
        var next = number + 1
        while next < document.paragraphs.count {
            let firstCharacter = document
                .runs(inParagraph: next)
                .lazy
                .flatMap { text[$0.range] }
                .first { !$0.isWhitespace }

            guard let firstCharacter else {
                next += 1                                   // blank paragraph, keep looking
                continue
            }
            return String(firstCharacter) == mark
        }
        return false
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
