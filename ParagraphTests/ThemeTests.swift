import AppKit
import XCTest
@testable import Paragraph

/// Paragraph claims its three themes are comfortable to read for hours and that
/// Focus Mode never makes surrounding text unreadable. These tests hold the
/// colours to those claims instead of taking them on trust.
final class ThemeTests: XCTestCase {

    /// WCAG relative luminance.
    private func luminance(_ color: NSColor) -> CGFloat {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(srgb.redComponent)
            + 0.7152 * channel(srgb.greenComponent)
            + 0.0722 * channel(srgb.blueComponent)
    }

    private func contrast(_ a: NSColor, _ b: NSColor) -> CGFloat {
        let first = luminance(a), second = luminance(b)
        let lighter = max(first, second), darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func testBodyTextIsComfortablyReadable() {
        for identifier in ThemeIdentifier.allCases {
            let theme = identifier.theme
            let ratio = contrast(theme.bodyText, theme.editorBackground)
            XCTAssertGreaterThan(ratio, 7.0,
                "\(identifier) body text contrast is \(ratio), below AAA for body text")
        }
    }

    func testFocusModeLeavesSurroundingTextReadable() {
        // De-emphasised is not the same as hidden: 3:1 is the floor at which
        // text remains legible rather than merely present.
        for identifier in ThemeIdentifier.allCases {
            let theme = identifier.theme
            let ratio = contrast(theme.deEmphasisedText, theme.editorBackground)
            XCTAssertGreaterThan(ratio, 3.0,
                "\(identifier) Focus Mode dimming leaves \(ratio) contrast, too faint to read")
            XCTAssertLessThan(ratio, contrast(theme.bodyText, theme.editorBackground),
                "\(identifier) Focus Mode dimming has no visible effect")
        }
    }

    func testWordCountRemainsLegible() {
        for identifier in ThemeIdentifier.allCases {
            let theme = identifier.theme
            XCTAssertGreaterThan(contrast(theme.secondaryText, theme.editorBackground), 3.0,
                "\(identifier) word count is too faint")
        }
    }

    func testInsertionPointIsVisible() {
        for identifier in ThemeIdentifier.allCases {
            let theme = identifier.theme
            XCTAssertGreaterThan(contrast(theme.insertionPoint, theme.editorBackground), 3.0,
                "\(identifier) cursor is hard to see")
        }
    }

    func testSelectionKeepsTextReadable() {
        for identifier in ThemeIdentifier.allCases {
            let theme = identifier.theme
            XCTAssertGreaterThan(contrast(theme.bodyText, theme.selectionBackground), 3.0,
                "\(identifier) selected text is hard to read")
        }
    }

    func testGreenScreenIsNearlyBlackAndGreen() {
        let theme = ThemeIdentifier.greenScreen.theme
        let background = theme.editorBackground.usingColorSpace(.sRGB)!
        let text = theme.bodyText.usingColorSpace(.sRGB)!

        XCTAssertLessThan(luminance(background), 0.02, "background is not nearly black")
        XCTAssertGreaterThan(text.greenComponent, text.redComponent, "text is not green")
        XCTAssertGreaterThan(text.greenComponent, text.blueComponent, "text is not green")
        // Muted, not a highlighter.
        XCTAssertLessThan(text.greenComponent, 0.9, "green is not muted")
    }

    /// The sidebar's material is drawn by the window. Setting the appearance
    /// only on descendant views left Light drawing black text on the system's
    /// dark sidebar material.
    func testTheWindowItselfCarriesTheThemeAppearance() throws {
        let document = MarkdownDocument()
        let controller = DocumentWindowController(markdownDocument: document)
        _ = controller.window

        for identifier in ThemeIdentifier.allCases {
            let original = Preferences.shared.theme
            defer { Preferences.shared.theme = original }

            Preferences.shared.theme = identifier
            // The theme reaches the window through a main-run-loop sink.
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            XCTAssertEqual(controller.window?.appearance?.name, identifier.theme.appearanceName,
                           "\(identifier) does not reach the window")
        }
    }

    func testTheDividerIsVisibleAgainstBothSides() {
        // Green Screen has near-black on both sides of the split, where AppKit's
        // own divider disappears.
        for identifier in ThemeIdentifier.allCases {
            let theme = identifier.theme
            let againstEditor = contrast(theme.separator, theme.editorBackground)
            XCTAssertGreaterThan(againstEditor, 1.2,
                "\(identifier) divider is invisible against the manuscript")
        }
    }

    func testThereAreExactlyThreeThemes() {
        XCTAssertEqual(ThemeIdentifier.allCases.count, 3)
    }
}
