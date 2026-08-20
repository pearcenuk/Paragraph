import Foundation

/// Counts the words a writer would say they have written.
///
/// # Counting rules
///
/// 1. Markdown markup is removed first (see ``MarkdownProse``), so headings,
///    bullets, emphasis markers, link destinations, code spans and fenced code
///    blocks do not contribute words. A link still contributes its visible text.
/// 2. A word is a maximal run of Unicode letters or digits.
/// 3. An apostrophe (`'` or `’`), hyphen (`-`, `‐`, `‑`), full stop or comma
///    does **not** split a word when it sits between two word characters.
///    So `don't`, `well-known`, `U.S.A.`, `3.14` and `1,000` are one word each.
/// 4. Any other character — including em dashes, ellipses and slashes — splits
///    words, so `dawn—light` counts as two.
/// 5. Emphasis inside a word does not split it: `un*bel*ievable` is one word.
///
/// The counter is a single forward pass and allocates nothing per word, so it
/// stays cheap enough to re-run on a debounce while the writer types.
public enum WordCounter {

    public static func count(markdown: String) -> Int {
        count(runs: MarkdownProse.runs(in: markdown), in: markdown)
    }

    public static func count(runs: [ProseRun], in text: String) -> Int {
        var words = 0
        var inWord = false

        for run in runs {
            if run.startsNewWord { inWord = false }

            var index = run.range.lowerBound
            while index < run.range.upperBound {
                let character = text[index]

                if isWordCharacter(character) {
                    if !inWord {
                        words += 1
                        inWord = true
                    }
                } else if isConnector(character), inWord {
                    // Stay inside the current word. A connector only ever joins
                    // what surrounds it, so a sentence-final full stop is ended
                    // by the space or line break that follows it.
                } else {
                    inWord = false
                }

                index = text.index(after: index)
            }
        }
        return words
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    static func isConnector(_ character: Character) -> Bool {
        switch character {
        case "'", "\u{2019}", "\u{02BC}": return true            // apostrophes
        case "-", "\u{2010}", "\u{2011}": return true            // hyphens
        case ".", ",": return true
        default: return false
        }
    }
}
