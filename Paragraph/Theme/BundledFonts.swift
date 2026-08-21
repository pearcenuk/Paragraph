import AppKit
import CoreText

/// Registers the fonts Paragraph ships with.
///
/// Registration is done in code rather than through `ATSApplicationFontsPath`
/// so it does not depend on where the build system happens to place the file
/// inside the bundle, and so a missing font is a graceful fallback rather than
/// a silently wrong typeface.
enum BundledFonts {

    /// IBM Plex Sans, under the SIL Open Font License 1.1. The licence travels
    /// with the font in the application bundle.
    static let writingFontFamily = "IBM Plex Sans"

    private static var didRegister = false

    static func register() {
        guard !didRegister else { return }
        didRegister = true

        let candidates = ["ttf", "otf"].flatMap {
            Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? []
        }
        for url in candidates where url.lastPathComponent.hasPrefix("IBMPlexSans") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// `true` once the writing font is actually available to use.
    static var writingFontIsAvailable: Bool {
        NSFontManager.shared.availableFontFamilies.contains(writingFontFamily)
    }
}
