import SwiftUI
import VikunjaCore

/// A two-option "API Token" / "Username & Password" segmented control, with
/// the password segment able to render disabled (dimmed, non-interactive)
/// instead of being hidden outright. Used by both `Onboarding` and
/// `Settings`' connection forms so the option is visible as soon as the
/// screen appears — it just stays disabled until a probe confirms the
/// server actually supports local auth, rather than popping in afterward.
///
/// A plain SwiftUI `Picker(.segmented)` can't disable one segment while
/// leaving the other enabled (it's backed by `UISegmentedControl`, which has
/// no such per-segment SwiftUI hook), so this draws its own two-button strip
/// instead.
public struct CredentialModePicker: View {
    @Binding private var selection: InstanceAccount.AuthMethod
    private let isPasswordEnabled: Bool

    public init(selection: Binding<InstanceAccount.AuthMethod>, isPasswordEnabled: Bool) {
        self._selection = selection
        self.isPasswordEnabled = isPasswordEnabled
    }

    public var body: some View {
        HStack(spacing: VikuSpacing.xxs) {
            segment(.apiToken, label: "API Token", isEnabled: true)
            segment(.password, label: "Username & Password", isEnabled: isPasswordEnabled)
        }
        .padding(VikuSpacing.xxs)
        .background(VikuColor.Surface.field, in: RoundedRectangle(cornerRadius: VikuRadius.sm, style: .continuous))
    }

    private func segment(_ mode: InstanceAccount.AuthMethod, label: String, isEnabled: Bool) -> some View {
        let isSelected = selection == mode
        return Button {
            selection = mode
        } label: {
            Text(label)
                .font(VikuFont.footnote)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VikuSpacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : (isEnabled ? Color.primary : VikuColor.textTertiary))
        .background(
            isSelected ? VikuColor.brandPrimary : Color.clear,
            in: RoundedRectangle(cornerRadius: VikuRadius.sm, style: .continuous),
        )
        .disabled(!isEnabled)
    }
}
