import AppKit

/// The manuscript editor.
///
/// This is a plain-text `NSTextView` on an explicitly constructed TextKit 1
/// stack. TextKit 1 is chosen deliberately, for two reasons that matter to
/// Paragraph specifically:
///
/// 1. Several views can attach their own layout manager to one shared
///    `NSTextStorage`, which is how the same file can appear in two windows
///    without becoming two documents.
/// 2. `NSLayoutManager` temporary attributes let Focus Mode dim surrounding
///    paragraphs without touching a single character of the writer's text.
///
/// Everything else — selection, cursor movement, undo, find, spelling,
/// Services, the contextual menu, VoiceOver — is `NSTextView`'s own behaviour,
/// left alone on purpose.
final class ParagraphTextView: NSTextView {

    var typewriterModeEnabled = false {
        didSet {
            guard typewriterModeEnabled != oldValue else { return }
            updateInsets()
            if typewriterModeEnabled { scrollCaretToTypewriterPosition() }
        }
    }

    var focusModeEnabled = false {
        didSet {
            guard focusModeEnabled != oldValue else { return }
            updateFocusHighlight()
        }
    }

    var theme: Theme = Preferences.shared.currentTheme {
        didSet { applyTheme() }
    }

    /// Builds a text view sharing `storage`, on its own TextKit 1 layout stack.
    static func make(sharing storage: NSTextStorage) -> ParagraphTextView {
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true

        let container = NSTextContainer(
            size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0

        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        return ParagraphTextView(frame: .zero, textContainer: container)
    }

    override init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        isEditable = true
        isSelectable = true
        allowsUndo = true
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        drawsBackground = true

        // The native find bar gives Find, Find Next/Previous and Replace.
        usesFindBar = true
        isIncrementalSearchingEnabled = true

        // Spelling is the only continuous analysis Paragraph shows in the text.
        isContinuousSpellCheckingEnabled = Preferences.shared.spellCheckingEnabled
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false

        // Substitutions follow the writer's macOS text settings, and can be
        // changed per application from Edit ▸ Substitutions.
        let defaults = UserDefaults.standard
        isAutomaticQuoteSubstitutionEnabled =
            defaults.object(forKey: "NSAutomaticQuoteSubstitutionEnabled") as? Bool ?? true
        isAutomaticDashSubstitutionEnabled =
            defaults.object(forKey: "NSAutomaticDashSubstitutionEnabled") as? Bool ?? true
        isAutomaticTextReplacementEnabled =
            defaults.object(forKey: "NSAutomaticTextReplacementEnabled") as? Bool ?? true
        // A Markdown source editor should not turn URLs into links.
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false

        setAccessibilityLabel(L10n.applicationName)
        applyTheme()
    }

    // MARK: - Theme

    private func applyTheme() {
        backgroundColor = theme.editorBackground
        insertionPointColor = theme.insertionPoint
        textColor = theme.bodyText
        font = EditorTypography.bodyFont()
        selectedTextAttributes = [
            .backgroundColor: theme.selectionBackground,
            .foregroundColor: theme.bodyText
        ]
        typingAttributes = MarkdownDocument.attributes(for: theme)
        updateFocusHighlight()
        needsDisplay = true
    }

    // MARK: - Layout

    /// Centres the writing column and, in Typewriter Mode, opens up enough room
    /// above and below for the first and last lines to reach the middle.
    func updateInsets() {
        guard let container = textContainer, let scrollView = enclosingScrollView else { return }

        let available = scrollView.contentSize.width
        let column = EditorLayout.columnWidth(availableWidth: available, font: EditorTypography.bodyFont())
        let horizontal = EditorLayout.horizontalInset(availableWidth: available, columnWidth: column)

        let vertical: CGFloat = typewriterModeEnabled
            ? max(EditorTypography.verticalPadding, scrollView.contentSize.height / 2)
            : EditorTypography.verticalPadding

        container.size = CGSize(width: column, height: .greatestFiniteMagnitude)
        textContainerInset = NSSize(width: horizontal, height: vertical)

        if frame.width != available {
            setFrameSize(NSSize(width: available, height: frame.height))
        }
    }

    // MARK: - Typewriter Mode

    /// Keeps the active line near the vertical middle of the editor.
    ///
    /// Scrolling is instant rather than animated. That is both calmer and the
    /// correct behaviour when Reduce Motion is switched on, so there is no
    /// separate code path for it.
    func scrollCaretToTypewriterPosition() {
        guard typewriterModeEnabled,
              let layoutManager,
              let textContainer,
              let scrollView = enclosingScrollView
        else { return }

        let selection = selectedRange()
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selection, actualCharacterRange: nil)

        let lineRect: NSRect
        if layoutManager.numberOfGlyphs == 0 {
            lineRect = NSRect(origin: .zero, size: CGSize(width: 0, height: EditorTypography.bodyPointSize))
        } else if selection.length == 0 {
            let glyphIndex = min(glyphRange.location, layoutManager.numberOfGlyphs - 1)
            lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        } else {
            lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        }

        let visibleHeight = scrollView.contentView.bounds.height
        guard visibleHeight > 0 else { return }

        let centreOfLine = lineRect.midY + textContainerOrigin.y
        let maximum = max(0, frame.height - visibleHeight)
        let target = min(max(0, centreOfLine - visibleHeight / 2), maximum)

        scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.origin.x, y: target))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - Focus Mode

    /// De-emphasises everything outside the paragraph the writer is in.
    ///
    /// Only the visible range is touched, so this stays cheap in a long chapter.
    /// Temporary attributes are used throughout: the document is never modified,
    /// and spelling squiggles, which are also temporary attributes, survive.
    func updateFocusHighlight() {
        guard let layoutManager, let textContainer, let storage = textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)

        guard focusModeEnabled, !shouldSuppressDimming else {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            return
        }
        guard let scrollView = enclosingScrollView, storage.length > 0 else { return }

        let visible = scrollView.contentView.bounds
            .offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        let visibleCharacters = layoutManager.characterRange(
            forGlyphRange: visibleGlyphs,
            actualGlyphRange: nil
        )
        guard visibleCharacters.length > 0 else { return }

        let paragraph = (storage.string as NSString).paragraphRange(for: selectedRange())

        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: visibleCharacters)
        let dimmed: [NSAttributedString.Key: Any] = [.foregroundColor: theme.deEmphasisedText]

        if let before = visibleCharacters.intersection(NSRange(location: 0, length: paragraph.location)) {
            layoutManager.setTemporaryAttributes(dimmed, forCharacterRange: before)
        }
        let afterStart = paragraph.location + paragraph.length
        if afterStart < full.length,
           let after = visibleCharacters.intersection(
               NSRange(location: afterStart, length: full.length - afterStart)
           ) {
            layoutManager.setTemporaryAttributes(dimmed, forCharacterRange: after)
        }
    }

    /// Increase Contrast means the writer has asked for less subtlety, not more.
    private var shouldSuppressDimming: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            || NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
    }

    // MARK: - Behaviour

    /// A file dragged onto the manuscript is opened, not typed into it.
    ///
    /// Without this, `NSTextView` would helpfully insert the file's path or
    /// contents into the writer's chapter, which is the opposite of helpful.
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppableFiles(in: sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppableFiles(in: sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = droppableFiles(in: sender)
        guard !files.isEmpty else { return super.performDragOperation(sender) }

        for url in files {
            DocumentOpener.open(url: url, placement: .tab(in: window))
        }
        return true
    }

    /// File URLs on the pasteboard that Paragraph can actually open. Anything
    /// else is left to `NSTextView`'s normal handling.
    func droppableFiles(in sender: NSDraggingInfo) -> [URL] {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return urls.filter {
            Workspace.supportedExtensions.contains($0.pathExtension.lowercased())
        }
    }

    /// Escape returns the writer to a clean editing state rather than doing
    /// nothing; the browser uses the same key to hand focus back here.
    override func cancelOperation(_ sender: Any?) {
        if selectedRange().length > 0 {
            setSelectedRange(NSRange(location: selectedRange().location, length: 0))
        }
    }
}

extension NSRange {
    /// `nil` rather than a zero-length range when two ranges do not overlap.
    func intersection(_ other: NSRange) -> NSRange? {
        let result = NSIntersectionRange(self, other)
        return result.length > 0 ? result : nil
    }
}
