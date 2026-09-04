import SwiftUI
import VikuDesignSystem

/// App version/build, external links (source, issue tracker, upstream
/// Vikunja project), a privacy note, and licensing info. Everything here is
/// static — no ViewModel, since there's no business logic or network call
/// involved (unlike every other screen in `Features/Settings`).
struct AboutView: View {
    private let appVersion: String
    private let buildNumber: String

    /// `bundle` defaults to `.main` but is overridable for previews/tests.
    init(bundle: Bundle = .main) {
        self.appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        self.buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                SettingsInfoRow(icon: "info.circle", title: "Version", value: appVersion)
                SettingsInfoRow(icon: "hammer", title: "Build", value: buildNumber)
            }

            Section {
                SettingsLinkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "Source Code",
                    url: AboutLinks.sourceCode,
                )
                SettingsLinkRow(icon: "ladybug", title: "Report a Problem", url: AboutLinks.reportProblem)
                SettingsLinkRow(icon: "arrow.up.forward.app", title: "Vikunja Project", url: AboutLinks.vikunjaProject)
            }

            Section {
                HStack(spacing: VikuSpacing.sm + VikuSpacing.xxs) {
                    SettingsRowIcon(systemName: "hand.raised")
                    Text("Privacy")
                        .font(VikuFont.body)
                        .foregroundStyle(Color.primary)
                }
            } footer: {
                Text(
                    "Viku only talks to the Vikunja instance you connect it to. "
                        + "Your tasks and credentials never pass through any other server.",
                )
            }

            Section {
                SettingsLinkRow(icon: "doc.text", title: "License (MIT)", url: AboutLinks.license)
            } footer: {
                Text(
                    "Viku is an independent, unofficial client and isn't affiliated with the Vikunja project. "
                        + "Vikunja itself is licensed under AGPLv3.",
                )
            }
        }
        .settingsListStyle()
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// The URLs backing `AboutView`'s link rows, gathered in one place so a repo
/// rename or move only needs updating here.
private enum AboutLinks {
    static let sourceCode = URL(string: "https://github.com/Seergs/vikuapp")!
    static let reportProblem = URL(string: "https://github.com/Seergs/vikuapp/issues/new")!
    static let vikunjaProject = URL(string: "https://vikunja.io")!
    static let license = URL(string: "https://github.com/Seergs/vikuapp/blob/main/LICENSE")!
}

/// A non-interactive settings row showing a title/value pair (e.g. "Version"
/// → "1.0").
private struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: VikuSpacing.sm + VikuSpacing.xxs) {
            SettingsRowIcon(systemName: icon)
            Text(title)
                .font(VikuFont.body)
                .foregroundStyle(Color.primary)
            Spacer()
            Text(value)
                .font(VikuFont.body)
                .foregroundStyle(VikuColor.textSecondary)
        }
    }
}

/// A settings row that opens an external URL in the system browser, styled
/// like `SettingsView`'s own navigation rows but with a trailing
/// external-link glyph instead of a chevron.
private struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: VikuSpacing.sm + VikuSpacing.xxs) {
                SettingsRowIcon(systemName: icon)
                Text(title)
                    .font(VikuFont.body)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VikuColor.textTertiary)
            }
            .contentShape(Rectangle())
        }
    }
}
