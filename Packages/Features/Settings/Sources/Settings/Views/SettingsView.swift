import SwiftUI
import VikunjaDesignSystem
import VikunjaNavigation

/// The Settings tab's landing screen. Real preferences aren't built yet — the
/// one thing here today is the entry point into connection management.
struct SettingsView: View {
    let activeAccountName: String
    let router: Router<SettingsRoute>

    var body: some View {
        List {
            Section {
                Button {
                    router.push(.connections)
                } label: {
                    HStack(spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
                        RoundedRectangle(cornerRadius: VikunjaRadius.sm - VikunjaSpacing.xs, style: .continuous)
                            .fill(VikunjaColor.brandPrimary.opacity(0.14))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VikunjaColor.brandPrimary)
                            }

                        VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                            Text("Connections")
                                .font(VikunjaFont.body)
                                .foregroundStyle(Color.primary)
                            Text(activeAccountName)
                                .font(VikunjaFont.footnote)
                                .foregroundStyle(VikunjaColor.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VikunjaColor.textTertiary)
                    }
                    // Without this, `.buttonStyle(.plain)` only treats the
                    // icon/text/chevron themselves as tappable, not the
                    // transparent gaps the `Spacer` leaves between them.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .settingsListStyle()
        .navigationTitle("Settings")
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
