import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// "Add a connection" screen. Purely presentational — all validation, probing
/// and persistence live in `InstanceSetupViewModel`, so future UI-only changes
/// (copy, styling, layout, button count) only ever touch this file.
public struct InstanceSetupView: View {
    @Bindable private var viewModel: InstanceSetupViewModel
    @State private var isTokenVisible = false
    private let onConnectionSaved: (InstanceAccount) -> Void

    public init(viewModel: InstanceSetupViewModel, onConnectionSaved: @escaping (InstanceAccount) -> Void) {
        self.viewModel = viewModel
        self.onConnectionSaved = onConnectionSaved
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: VikunjaSpacing.lg) {
                header
                fields

                testConnectionButton

                if let statusText {
                    statusBanner(text: statusText, isSuccess: viewModel.validationState == .success)
                }

                saveButton
            }
            .padding(VikunjaSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .hideNavigationBar()
        .task { await viewModel.loadSavedAccounts() }
        .onChange(of: viewModel.savedAccount) { _, savedAccount in
            if let savedAccount {
                onConnectionSaved(savedAccount)
            }
        }
    }

    private var header: some View {
        VStack(spacing: VikunjaSpacing.md) {
            RoundedRectangle(cornerRadius: VikunjaRadius.lg, style: .continuous)
                .fill(VikunjaColor.brandPrimary)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(spacing: VikunjaSpacing.xs) {
                Text("Connect your instance")
                    .font(VikunjaFont.title2)
                    .fontWeight(.heavy)

                Text("This app connects to your own Vikunja server. Enter your instance's details to get started.")
                    .font(VikunjaFont.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(VikunjaColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, VikunjaSpacing.lg)
    }

    private var fields: some View {
        VStack(spacing: VikunjaSpacing.md) {
            OnboardingField(label: "Connection name", text: $viewModel.displayName, placeholder: "e.g. Office server")
                .autocapitalized(.words)

            OnboardingField(label: "Instance URL", text: $viewModel.urlText, placeholder: "https://tasks.example.com")
                .autocapitalized(.never)
                .autocorrectionDisabled()
                .keyboardTypeURL()

            OnboardingField(
                label: "API token",
                text: $viewModel.apiToken,
                placeholder: "vkj_...",
                isSecure: !isTokenVisible,
                hint: "Generate one on your Vikunja instance: Settings → API Tokens.",
                trailingSystemImage: isTokenVisible ? "eye.slash" : "eye",
                trailingAction: { isTokenVisible.toggle() }
            )
            .autocapitalized(.never)
            .autocorrectionDisabled()
        }
    }

    private var testConnectionButton: some View {
        Button {
            Task { await viewModel.testConnection() }
        } label: {
            HStack(spacing: VikunjaSpacing.sm) {
                if viewModel.isSaving {
                    ProgressView()
                }
                Text(viewModel.isSaving ? "Testing connection…" : "Test Connection")
                    .font(VikunjaFont.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VikunjaSpacing.md)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
        .opacity(viewModel.canTestConnection ? 1 : 0.5)
        .disabled(!viewModel.canTestConnection || viewModel.isSaving)
    }

    private func statusBanner(text: String, isSuccess: Bool) -> some View {
        let backgroundTint = isSuccess ? VikunjaColor.Semantic.success : VikunjaColor.Semantic.danger
        let textTint = isSuccess ? VikunjaColor.Semantic.successText : VikunjaColor.Semantic.dangerText
        return HStack(spacing: VikunjaSpacing.sm) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(text)
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
        }
        .foregroundStyle(textTint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VikunjaSpacing.md)
        .padding(.vertical, VikunjaSpacing.sm)
        .background(backgroundTint.opacity(0.12), in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.saveConnection() }
        } label: {
            Text("Save & Continue")
                .font(VikunjaFont.body)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VikunjaSpacing.md)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(VikunjaColor.brandPrimary, in: RoundedRectangle(cornerRadius: VikunjaRadius.md, style: .continuous))
        .opacity(viewModel.canSave ? 1 : 0.4)
        .disabled(!viewModel.canSave || viewModel.isSaving)
    }

    private var statusText: String? {
        switch viewModel.validationState {
        case .idle, .validating:
            return nil
        case .success:
            return "Connection successful."
        case let .failure(message):
            return message
        }
    }
}

/// A single labeled input row: label above a rounded field-background box,
/// with an optional trailing icon button (e.g. show/hide the API token) and
/// an optional hint line below.
private struct OnboardingField: View {
    let label: String
    @Binding var text: String
    var placeholder: String
    var isSecure: Bool = false
    var hint: String?
    var trailingSystemImage: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.xs) {
            Text(label)
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(VikunjaColor.textSecondary)

            HStack(spacing: VikunjaSpacing.sm) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(VikunjaFont.body)

                if let trailingSystemImage, let trailingAction {
                    Button(action: trailingAction) {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 14))
                            .foregroundStyle(VikunjaColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VikunjaSpacing.md)
            .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))

            if let hint {
                Text(hint)
                    .font(VikunjaFont.caption)
                    .foregroundStyle(VikunjaColor.textSecondary)
            }
        }
    }
}

/// `textInputAutocapitalization`/`keyboardType` are iOS/watchOS-only, but this
/// package also builds for macOS to run its tests — these no-op there.
private extension View {
    @ViewBuilder
    func autocapitalized(_ style: TextInputAutocapitalizationStyle) -> some View {
        #if os(iOS)
        textInputAutocapitalization(style)
        #else
        self
        #endif
    }

    @ViewBuilder
    func keyboardTypeURL() -> some View {
        #if os(iOS)
        keyboardType(.URL)
        #else
        self
        #endif
    }

    @ViewBuilder
    func hideNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

#if os(iOS)
private typealias TextInputAutocapitalizationStyle = TextInputAutocapitalization
#else
private enum TextInputAutocapitalizationStyle {
    case never
    case words
}
#endif
