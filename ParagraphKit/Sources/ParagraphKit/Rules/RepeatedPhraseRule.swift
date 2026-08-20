import Foundation

/// Reports a short phrase that reappears close to where it was last used.
///
/// The rule is deliberately conservative: a three-word phrase, a nearby window,
/// and phrases made entirely of common function words are ignored. It reports
/// proximity, which is mechanical, and says nothing about whether the repetition
/// is good writing — sometimes it is exactly right.
///
/// The stop-word set is injected rather than baked in, so a future contributor
/// can supply one for another language without changing the rule.
public struct RepeatedPhraseRule: WritingCheckRule {
    public let identifier = "repeated-phrase"

    /// Common English function words. Supplying a different set is how this rule
    /// would be adapted to another language.
    public static let defaultStopWords: Set<String> = [
        "a", "an", "and", "as", "at", "be", "been", "but", "by", "for", "from",
        "had", "has", "have", "he", "her", "him", "his", "i", "if", "in", "into",
        "is", "it", "its", "me", "my", "no", "not", "of", "on", "or", "out",
        "she", "so", "than", "that", "the", "their", "them", "then", "there",
        "they", "this", "to", "up", "was", "we", "were", "what", "when", "which",
        "who", "will", "with", "you", "your"
    ]

    private let phraseLength: Int
    private let windowInWords: Int
    private let stopWords: Set<String>

    public init(
        phraseLength: Int = 3,
        windowInWords: Int = 50,
        stopWords: Set<String> = RepeatedPhraseRule.defaultStopWords
    ) {
        self.phraseLength = max(2, phraseLength)
        self.windowInWords = max(phraseLength, windowInWords)
        self.stopWords = stopWords
    }

    public func check(_ document: ProseDocument) -> [WritingCheckIssue] {
        let words = document.words
        guard words.count >= phraseLength * 2 else { return [] }

        var repeats: [Range<String.Index>] = []
        var lastSeen: [String: Int] = [:]

        for start in 0...(words.count - phraseLength) {
            let phraseWords = words[start..<(start + phraseLength)]

            // Ignore phrases that are nothing but function words: `out of the`
            // repeating twice in a page is not information.
            guard phraseWords.contains(where: { !stopWords.contains($0.folded) }) else { continue }

            let key = phraseWords.map(\.folded).joined(separator: " ")

            if let previous = lastSeen[key],
               start - previous >= phraseLength,        // no self-overlap
               start - previous <= windowInWords {
                repeats.append(
                    phraseWords.first!.range.lowerBound..<phraseWords.last!.range.upperBound
                )
            }
            lastSeen[key] = start
        }

        return merge(repeats, in: document)
    }

    /// A single repeated stretch matches at several overlapping offsets. Report
    /// the stretch once, spanning the whole of it, rather than once per window.
    private func merge(
        _ ranges: [Range<String.Index>],
        in document: ProseDocument
    ) -> [WritingCheckIssue] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }

        var merged: [Range<String.Index>] = [sorted[0]]
        for range in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            if range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<Swift.max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }

        return merged.map { range in
            WritingCheckIssue(
                ruleIdentifier: identifier,
                severity: .warning,
                finding: .repeatedPhrase(String(document.text[range])),
                range: range,
                line: document.lineNumber(at: range.lowerBound)
            )
        }
    }
}
