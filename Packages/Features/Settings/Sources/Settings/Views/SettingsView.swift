import SwiftUI
import VikuDesignSystem
import VikuNavigation
import VikunjaCore

/// The Settings tab's landing screen. The entry points here today are
/// appearance, connection management, and label management.
struct SettingsView: View {
    let activeAccountName: String
    let themeStore: AppThemeStoring
    let router: Router<SettingsRoute>

    var body: some View {
        List {
            // One section, not three, so these render as a single grouped
            // card (matching Settings.app) instead of one card per row.
            Section {
                Picker(selection: themeBinding) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                } label: {
                    HStack(spacing: VikuSpacing.sm + VikuSpacing.xxs) {
                        SettingsRowIcon(systemName: "circle.lefthalf.filled")
                        Text("Appearance")
                    }
                }

                SettingsNavigationRow(
                    icon: "server.rack",
                    title: "Connections",
                    subtitle: activeAccountName,
                ) {
                    router.push(.connections)
                }

                SettingsNavigationRow(
                    icon: "tag",
                    title: "Manage Labels",
                    subtitle: "View, edit, and create labels",
                ) {
                    router.push(.manageLabels)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Settings")
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(get: { themeStore.theme }, set: { themeStore.setTheme($0) })
    }
}

/// A tappable settings row: tinted icon tile, title, one-line subtitle, and a
/// trailing chevron. The whole row is the hit target.
private struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikuSpacing.sm + VikuSpacing.xxs) {
                SettingsRowIcon(systemName: icon)

                VStack(alignment: .leading, spacing: VikuSpacing.xxs) {
                    Text(title)
                        .font(VikuFont.body)
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(VikuFont.footnote)
                        .foregroundStyle(VikuColor.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VikuColor.textTertiary)
            }
            // Without this, `.buttonStyle(.plain)` only treats the
            // icon/text/chevron themselves as tappable, not the transparent
            // gaps the `Spacer` leaves between them.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The tinted icon tile shared by every settings row, plain or navigating.
private struct SettingsRowIcon: View {
    let systemName: String

    var body: some View {
        RoundedRectangle(cornerRadius: VikuRadius.sm - VikuSpacing.xs, style: .continuous)
            .fill(VikuColor.brandPrimary.opacity(0.14))
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VikuColor.brandPrimary)
            }
    }
}

private extension View {
    @ViewBuilder
    func settingsListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}
