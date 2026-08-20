import AppKit
import SwiftUI

/// A reference, not an editor.
///
/// The shortcuts shown here are read from the same ``AppCommand`` table the menu
/// bar is built from, so the two cannot disagree. There is no "hold Command to
/// see hints" overlay: the menus and this window are enough.
struct ShortcutsView: View {
    private struct Row: Identifiable {
        let id: String
        let title: String
        let shortcut: String
    }

    private var groups: [(ShortcutCategory, [Row])] {
        ShortcutCategory.allCases.compactMap { category in
            let rows = AppCommand.allCases
                .filter { $0.category == category && $0.shortcut != nil }
                .map { Row(id: $0.rawValue, title: $0.title, shortcut: $0.shortcut!.displayString) }
            return rows.isEmpty ? nil : (category, rows)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.shortcutsIntro)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups, id: \.0) { category, rows in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.localizedTitle)
                                .font(.system(size: 12, weight: .semibold))
                            ForEach(rows) { row in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.title)
                                        .font(.system(size: 12))
                                    Spacer(minLength: 24)
                                    Text(row.shortcut)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(row.title), \(row.shortcut)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 420, height: 520)
    }
}

final class ShortcutsWindowController: NSWindowController {
    static let shared = ShortcutsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.shortcutsTitle
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = NSHostingView(rootView: ShortcutsView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
