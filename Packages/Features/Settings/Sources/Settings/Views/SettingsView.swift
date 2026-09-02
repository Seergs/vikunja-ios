import SwiftUI
import VikuDesignSystem
import VikuNavigation

/// The Settings tab's landing screen. Real preferences aren't built yet — the
/// entry points here today are connection management and label management.
struct SettingsView: View {
    let activeAccountName: String
    let router: Router<SettingsRoute>

    var body: some View {
        List {
            Section {
                SettingsNavigationRow(
                    icon: "server.rack",
                    title: "Connections",
                    subtitle: activeAccountName,
                ) {
                    router.push(.connections)
                }
            }

            Section {
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
                RoundedRectangle(cornerRadius: VikuRadius.sm - VikuSpacing.xs, style: .continuous)
                    .fill(VikuColor.brandPrimary.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VikuColor.brandPrimary)
                    }

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
