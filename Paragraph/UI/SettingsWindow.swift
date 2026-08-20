import AppKit
import SwiftUI

/// Settings, kept deliberately small.
///
/// Three decisions live here. Everything else is either a mode toggled from the
/// menus, or a choice Paragraph has already made on the writer's behalf. There
/// is no Advanced tab, and nothing here can change how a file is written.
struct SettingsView: View {
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        Form {
            Picker(L10n.settingsTheme, selection: $preferences.theme) {
                ForEach(ThemeIdentifier.allCases, id: \.self) { identifier in
                    Text(identifier.theme.localizedName).tag(identifier)
                }
            }
            .pickerStyle(.inline)
            .accessibilityLabel(L10n.settingsTheme)

            Divider().padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 3) {
                Toggle(L10n.settingsRestoreSession, isOn: $preferences.restorePreviousSession)
                Text(L10n.settingsRestoreSessionHelp)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Toggle(L10n.settingsSpellChecking, isOn: $preferences.spellCheckingEnabled)
                Text(L10n.settingsSpellCheckingHelp)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settingsTitle
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = NSHostingView(rootView: SettingsView())
        super.init(window: window)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
