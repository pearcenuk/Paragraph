import SwiftUI

/// The word count: the only statistic Paragraph shows while you write.
///
/// No characters, no reading time, no daily total, no goal, no streak.
struct WordCountBar: View {
    let count: Int
    let theme: Theme

    var body: some View {
        HStack {
            Spacer()
            Text(L10n.wordCount(count))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor(Color(nsColor: theme.secondaryText))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(nsColor: theme.editorBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: theme.separator))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.wordCount(count))
    }
}

/// What a banner is telling the writer.
enum EditorBannerKind: Equatable {
    case externalChange
    case downloadingFromCloud
    case unavailable(String)
}

/// A quiet strip above the text, used only when something about the *file*
/// needs saying. It never reports on the writing itself.
struct EditorBanner: View {
    let kind: EditorBannerKind
    let theme: Theme
    var onReload: () -> Void = {}
    var onKeep: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundColor(Color(nsColor: theme.secondaryText))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(nsColor: theme.bodyText))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: theme.secondaryText))
                }
            }

            Spacer(minLength: 8)

            if case .externalChange = kind {
                Button(L10n.externalChangeKeep, action: onKeep)
                Button(L10n.externalChangeReload, action: onReload)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: theme.editorBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(nsColor: theme.separator)).frame(height: 1)
        }
    }

    private var symbolName: String {
        switch kind {
        case .externalChange: return "exclamationmark.triangle"
        case .downloadingFromCloud: return "arrow.down.circle"
        case .unavailable: return "icloud.slash"
        }
    }

    private var title: String {
        switch kind {
        case .externalChange: return L10n.externalChangeTitle
        case .downloadingFromCloud: return L10n.downloadingFromCloud
        case .unavailable(let message): return message
        }
    }

    private var detail: String? {
        switch kind {
        case .externalChange: return L10n.externalChangeDetail
        case .downloadingFromCloud, .unavailable: return nil
        }
    }
}
