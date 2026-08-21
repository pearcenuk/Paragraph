import AppKit
import Combine
import SwiftUI

/// One view of one document.
///
/// A document may have several of these — one per tab or window — each with its
/// own cursor, selection and scroll position, all editing the same
/// `NSTextStorage`. That separation is what keeps two windows onto one file from
/// becoming two files.
final class EditorViewController: NSViewController {

    let document: MarkdownDocument

    private(set) var textView: ParagraphTextView!
    private var scrollView: NSScrollView!
    private var wordCountHost: NSHostingView<WordCountBar>!
    private var bannerHost: NSView?
    private var bannerTopConstraint: NSLayoutConstraint?

    private var observers: Set<AnyCancellable> = []
    private var savedSelection: NSRange?

    init(document: MarkdownDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - View

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        textView = ParagraphTextView.make(sharing: document.textStorage)
        textView.delegate = self
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.documentView = textView

        // Focus Mode follows the visible range, so the editor needs to know when
        // that range moves.
        scrollView.contentView.postsBoundsChangedNotifications = true

        wordCountHost = NSHostingView(
            rootView: WordCountBar(count: document.wordCount, theme: Preferences.shared.currentTheme)
        )
        wordCountHost.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scrollView)
        container.addSubview(wordCountHost)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: wordCountHost.topAnchor),

            wordCountHost.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wordCountHost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wordCountHost.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme(Preferences.shared.currentTheme)
        applyModes()
        observe()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        textView.updateInsets()
        textView.updateFocusHighlight()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
        textView.updateInsets()
        if Preferences.shared.typewriterMode {
            textView.scrollCaretToTypewriterPosition()
        }
    }

    // MARK: - Observation

    private func observe() {
        let preferences = Preferences.shared

        preferences.$theme
            .receive(on: RunLoop.main)
            .sink { [weak self] identifier in self?.applyTheme(identifier.theme) }
            .store(in: &observers)

        preferences.$editorFontSize
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // The measure is derived from the font, so the column has to be
                // remeasured as well as restyled.
                self.textView.theme = Preferences.shared.currentTheme
                self.textView.updateInsets()
                self.textView.updateFocusHighlight()
                if Preferences.shared.typewriterMode {
                    self.textView.scrollCaretToTypewriterPosition()
                }
            }
            .store(in: &observers)

        preferences.$typewriterMode
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.textView.typewriterModeEnabled = enabled
                self?.textView.updateInsets()
            }
            .store(in: &observers)

        preferences.$focusMode
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.textView.focusModeEnabled = enabled }
            .store(in: &observers)

        preferences.$spellCheckingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.textView.isContinuousSpellCheckingEnabled = enabled
            }
            .store(in: &observers)

        preferences.$wordCountVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.wordCountHost.isHidden = !visible }
            .store(in: &observers)

        document.$wordCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in self?.updateWordCount(count) }
            .store(in: &observers)

        document.$hasExternalConflict
            .receive(on: RunLoop.main)
            .sink { [weak self] conflict in
                self?.showBanner(conflict ? .externalChange : nil)
            }
            .store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSView.boundsDidChangeNotification, object: scrollView.contentView)
            .sink { [weak self] _ in self?.textView.updateFocusHighlight() }
            .store(in: &observers)

        // A reload replaces the whole text; put the cursor back where it was.
        NotificationCenter.default
            .publisher(for: .paragraphDocumentWillReload, object: document)
            .sink { [weak self] _ in self?.savedSelection = self?.textView.selectedRange() }
            .store(in: &observers)

        NotificationCenter.default
            .publisher(for: .paragraphDocumentDidReload, object: document)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.restoreSelectionAfterReload() }
            .store(in: &observers)
    }

    private func applyModes() {
        textView.typewriterModeEnabled = Preferences.shared.typewriterMode
        textView.focusModeEnabled = Preferences.shared.focusMode
        textView.isContinuousSpellCheckingEnabled = Preferences.shared.spellCheckingEnabled
        wordCountHost.isHidden = !Preferences.shared.wordCountVisible
        updateWordCount(document.wordCount)
    }

    private func applyTheme(_ theme: Theme) {
        textView.theme = theme
        scrollView.backgroundColor = theme.editorBackground
        view.appearance = theme.appearance
        updateWordCount(document.wordCount)
        if let banner = currentBannerKind { showBanner(banner) }
    }

    private func updateWordCount(_ count: Int) {
        wordCountHost.rootView = WordCountBar(count: count, theme: Preferences.shared.currentTheme)
    }

    private func restoreSelectionAfterReload() {
        guard let selection = savedSelection else { return }
        savedSelection = nil
        let length = textView.textStorage?.length ?? 0
        let location = min(selection.location, length)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.updateFocusHighlight()
    }

    // MARK: - Banner

    private var currentBannerKind: EditorBannerKind?

    func showBanner(_ kind: EditorBannerKind?) {
        currentBannerKind = kind
        bannerHost?.removeFromSuperview()
        bannerHost = nil

        guard let kind else { return }

        let banner = EditorBanner(
            kind: kind,
            theme: Preferences.shared.currentTheme,
            onReload: { [weak self] in self?.document.reloadFromDisk() },
            onKeep: { [weak self] in self?.document.keepCurrentVersion() }
        )
        let host = NSHostingView(rootView: banner)
        host.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.topAnchor.constraint(equalTo: view.topAnchor)
        ])
        bannerHost = host
    }

    // MARK: - View state, for session restoration

    var selectedRange: NSRange {
        get { textView.selectedRange() }
        set {
            let length = textView.textStorage?.length ?? 0
            let location = min(newValue.location, length)
            let span = min(newValue.length, length - location)
            textView.setSelectedRange(NSRange(location: location, length: span))
        }
    }

    /// Scroll position as a fraction of the document, which survives a window
    /// being a different size than it was last time.
    var scrollFraction: Double {
        get {
            let visible = scrollView.contentView.bounds
            let total = max(1, textView.frame.height - visible.height)
            return Double(max(0, min(1, visible.origin.y / total)))
        }
        set {
            view.layoutSubtreeIfNeeded()
            let visible = scrollView.contentView.bounds
            let total = max(0, textView.frame.height - visible.height)
            let y = CGFloat(max(0, min(1, newValue))) * total
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    func focusEditor() {
        view.window?.makeFirstResponder(textView)
    }
}

// MARK: - NSTextViewDelegate

extension EditorViewController: NSTextViewDelegate {

    func textViewDidChangeSelection(_ notification: Notification) {
        textView.updateFocusHighlight()
        textView.scrollCaretToTypewriterPosition()
    }

    func textDidChange(_ notification: Notification) {
        textView.scrollCaretToTypewriterPosition()
    }
}
