import AppKit
import UniformTypeIdentifiers

/// Small adjustments to the standard document controller.
///
/// `NSDocumentController` is doing the important work: one document per file,
/// the open and save panels, the recent-documents list, and the checks that stop
/// a document being saved over a newer version on disk.
final class ParagraphDocumentController: NSDocumentController {

    override var defaultType: String? { "net.daringfireball.markdown" }

    /// Autosave in place, at a gentle interval. A writer should not be able to
    /// lose an afternoon's work by forgetting to press Command-S.
    override init() {
        super.init()
        autosavingDelay = 5
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        autosavingDelay = 5
    }

    override func runModalOpenPanel(
        _ openPanel: NSOpenPanel,
        forTypes types: [String]?
    ) -> Int {
        openPanel.allowedContentTypes = Self.openableTypes
        openPanel.allowsOtherFileTypes = true
        return super.runModalOpenPanel(openPanel, forTypes: types)
    }

    private static var openableTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let markdown = UTType("net.daringfireball.markdown") { types.insert(markdown, at: 0) }
        return types
    }
}
