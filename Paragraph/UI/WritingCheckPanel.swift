import AppKit
import SwiftUI
import ParagraphKit

/// A Writing Check result, resolved to a range the editor can select.
struct PresentedIssue: Identifiable {
    let id = UUID()
    let severity: WritingCheckSeverity
    let message: String
    let line: Int
    let range: NSRange

    var severityLabel: String {
        switch severity {
        case .error: return L10n.severityError
        case .warning: return L10n.severityWarning
        }
    }

    /// Severity is never communicated by colour alone: every row carries the
    /// word "Error" or "Warning" and a distinct symbol.
    var symbolName: String {
        switch severity {
        case .error: return "exclamationmark.octagon"
        case .warning: return "exclamationmark.triangle"
        }
    }
}

final class WritingCheckModel: ObservableObject {
    @Published var issues: [PresentedIssue] = []
    @Published var documentName: String?
    @Published var hasRun = false

    var errorCount: Int { issues.filter { $0.severity == .error }.count }
    var warningCount: Int { issues.filter { $0.severity == .warning }.count }
}

struct WritingCheckView: View {
    @ObservedObject var model: WritingCheckModel
    var onSelect: (PresentedIssue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.issues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.hasRun ? L10n.writingCheckClean : L10n.writingCheckNoDocument)
                        .font(.system(size: 13, weight: .medium))
                    if model.hasRun {
                        Text(L10n.writingCheckCleanDetail)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text(L10n.writingCheckSummary(errors: model.errorCount, warnings: model.warningCount))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()

                List {
                    ForEach(WritingCheckSeverity.allCases, id: \.self) { severity in
                        let matching = model.issues.filter { $0.severity == severity }
                        if !matching.isEmpty {
                            Section(header: Text(severity == .error
                                                 ? L10n.severityError
                                                 : L10n.severityWarning)) {
                                ForEach(matching) { issue in
                                    IssueRow(issue: issue)
                                        .contentShape(Rectangle())
                                        .onTapGesture { onSelect(issue) }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 380, minHeight: 260)
    }
}

private struct IssueRow: View {
    let issue: PresentedIssue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: issue.symbolName)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.lineLabel(issue.line))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        // The message already ends in a full stop; adding another produces
        // "never closed.. Line 5" when VoiceOver reads it.
        .accessibilityLabel("\(issue.severityLabel). \(issue.message) \(L10n.lineLabel(issue.line))")
    }
}

/// Writing Check behaves like running a compiler: the writer asks for it, the
/// results appear in their own window, and nothing is changed in the manuscript.
/// No squiggle is ever left behind in the text.
final class WritingCheckWindowController: NSWindowController {
    static let shared = WritingCheckWindowController()

    private let model = WritingCheckModel()
    private var appearance: ThemeAppearanceBinder?
    private weak var targetEditor: EditorViewController?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.writingCheckTitle
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        super.init(window: window)

        window.contentView = NSHostingView(
            rootView: WritingCheckView(model: model) { [weak self] issue in
                self?.reveal(issue)
            }
        )
        appearance = ThemeAppearanceBinder(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Runs the check and shows the results.
    func run(on windowController: DocumentWindowController?) {
        guard let windowController else {
            model.issues = []
            model.hasRun = false
            showWindow(nil)
            return
        }

        let document = windowController.markdownDocument
        targetEditor = windowController.editorViewController

        let text = document.textStorage.string
        let issues = WritingCheck().run(on: text)

        model.documentName = document.displayName
        model.hasRun = true
        model.issues = issues.map { issue in
            PresentedIssue(
                severity: issue.severity,
                message: Self.message(for: issue.finding),
                line: issue.line,
                range: NSRange(issue.range, in: text)
            )
        }
        showWindow(nil)
        let name = document.displayName ?? L10n.untitledDocument
        window?.title = "\(L10n.writingCheckTitle) — \(name)"
    }

    private func reveal(_ issue: PresentedIssue) {
        guard let editor = targetEditor else { return }
        editor.view.window?.makeKeyAndOrderFront(nil)
        editor.selectedRange = issue.range
        editor.focusEditor()
        editor.textView.scrollRangeToVisible(issue.range)
    }

    /// The rules describe findings structurally; the wording lives here, where
    /// translators can reach it.
    private static func message(for finding: WritingCheckFinding) -> String {
        switch finding {
        case .unmatchedOpeningQuote(let mark): return L10n.unmatchedOpeningQuote(mark)
        case .unmatchedClosingQuote(let mark): return L10n.unmatchedClosingQuote(mark)
        case .unmatchedOpeningDelimiter(let mark): return L10n.unmatchedOpeningDelimiter(mark)
        case .unmatchedClosingDelimiter(let mark): return L10n.unmatchedClosingDelimiter(mark)
        case .duplicateWord(let word): return L10n.duplicateWord(word)
        case .repeatedPhrase(let phrase): return L10n.repeatedPhrase(phrase)
        }
    }
}
