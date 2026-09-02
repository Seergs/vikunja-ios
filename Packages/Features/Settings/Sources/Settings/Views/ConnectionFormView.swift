import SwiftUI
import VikuDesignSystem
import VikuNavigation

/// The add/edit connection screen: name, instance URL, API token, a "Test
/// Connection" probe, and — only in edit mode — a "Delete Connection" action.
/// Pushed onto the Settings tab's own stack (from `ConnectionsListView`)
/// rather than presented as a sheet, since it's a step within that stack
/// rather than an independent flow.
struct ConnectionFormView: View {
    @State private var viewModel: ConnectionFormViewModel
    let router: Router<SettingsRoute>
    @State private var isTokenVisible = false
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFocused: Bool

    /// Takes a factory rather than an already-built view model — see
    /// `ConnectionsListView.init`'s doc comment for why this has to be
    /// `@State`-owned instead of a plain `@Bindable` property.
    init(makeViewModel: @escaping () -> ConnectionFormViewModel, router: Router<SettingsRoute>) {
        _viewModel = State(initialValue: makeViewModel())
        self.router = router
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VikunjaSpacing.lg) {
                VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
                    FormField(label: "Connection Name", placeholder: "e.g. Office Server", text: $viewModel.displayName)
                        .focused($isNameFocused)

                    FormField(label: "Instance URL", placeholder: "https://tasks.yourcompany.com", text: $viewModel.urlText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()

                    tokenField
                }

                testConnectionButton

                if case let .failure(message) = viewModel.validationState {
                    StatusBanner(style: .danger, message: message)
                } else if viewModel.validationState == .success {
                    StatusBanner(style: .success, message: viewModel.savedAccount != nil ? "Saved" : "Connection successful")
                }

                saveButton

                if viewModel.isEditing {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Text("Delete Connection")
                            .font(VikunjaFont.body)
                            .fontWeight(.bold)
                            .foregroundStyle(VikunjaColor.Semantic.danger)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VikunjaSpacing.sm)
                }
            }
            .padding(VikunjaSpacing.md)
        }
        .navigationTitle(viewModel.isEditing ? "Edit Connection" : "New Connection")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.load()
            isNameFocused = viewModel.displayName.isEmpty
        }
        .onChange(of: viewModel.savedAccount) { _, savedAccount in
            if savedAccount != nil {
                router.pop()
            }
        }
        .confirmationDialog(
            "Remove this connection?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible,
        ) {
            Button("Remove Connection", role: .destructive) {
                Task {
                    if await viewModel.deleteConnection() {
                        router.pop()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var tokenField: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            FieldLabel("API Token")

            HStack(spacing: VikunjaSpacing.sm) {
                Group {
                    if isTokenVisible {
                        TextField("vkj_...", text: $viewModel.apiToken)
                    } else {
                        SecureField("vkj_...", text: $viewModel.apiToken)
                    }
                }
                .font(VikunjaFont.body)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

                Button {
                    isTokenVisible.toggle()
                } label: {
                    Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                        .foregroundStyle(VikunjaColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTokenVisible ? "Hide token" : "Show token")
            }
            .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))

            Text("Generate it on your Vikunja instance: Settings → API Tokens.")
                .font(VikunjaFont.caption)
                .foregroundStyle(VikunjaColor.textTertiary)
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
                    .font(VikunjaFont.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canTestConnection)
        .opacity(viewModel.canTestConnection ? 1 : 0.5)
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            Text(viewModel.isEditing ? "Save Connection" : "Save and Connect")
                .font(VikunjaFont.body)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xs)
                .background(VikunjaColor.brandPrimary, in: RoundedRectangle(cornerRadius: VikunjaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSave)
        .opacity(viewModel.canSave ? 1 : 0.4)
    }
}

private struct FieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(VikunjaFont.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(VikunjaColor.textSecondary)
    }
}

/// A labeled single-line text field in a rounded field surface — the shared
/// shape behind "Connection Name" and "Instance URL".
private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            FieldLabel(label)
            TextField(placeholder, text: $text)
                .font(VikunjaFont.body)
                .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
                .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
                .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
        }
    }
}

/// Same tinted-card language as `Projects`' `CreateProjectSheetView` save
/// error banner — duplicated rather than shared since the design system has
/// no reusable banner component yet, and this one also covers a success
/// state theirs doesn't need.
private struct StatusBanner: View {
    enum Style { case success, danger }

    let style: Style
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            Image(systemName: style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(foreground)
            Text(message)
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(foreground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background.opacity(0.12), in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }

    private var foreground: Color {
        style == .success ? VikunjaColor.Semantic.successText : VikunjaColor.Semantic.dangerText
    }

    private var background: Color {
        style == .success ? VikunjaColor.Semantic.success : VikunjaColor.Semantic.danger
    }
}
