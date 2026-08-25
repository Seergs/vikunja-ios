import SwiftUI

/// "Add a connection" screen. Purely presentational — all validation, probing
/// and persistence live in `InstanceSetupViewModel`, so future UI-only changes
/// (copy, styling, layout, button count) only ever touch this file.
public struct InstanceSetupView: View {
    @Bindable private var viewModel: InstanceSetupViewModel

    public init(viewModel: InstanceSetupViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("Connection") {
                TextField("Name", text: $viewModel.displayName)
                    .autocapitalized(.words)

                TextField("Server address", text: $viewModel.urlText)
                    .autocapitalized(.never)
                    .autocorrectionDisabled()
                    .keyboardTypeURL()

                SecureField("API token", text: $viewModel.apiToken)
                    .autocapitalized(.never)
                    .autocorrectionDisabled()
            }

            if let statusText {
                Section {
                    Label(statusText, systemImage: statusSymbolName)
                        .foregroundStyle(statusColor)
                }
            }

            Section {
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(!viewModel.canTestConnection || viewModel.isSaving)

                Button {
                    Task { await viewModel.saveConnection() }
                } label: {
                    Text("Save & Continue")
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
        .navigationTitle("Add Instance")
        .task { await viewModel.loadSavedAccounts() }
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

    private var statusSymbolName: String {
        switch viewModel.validationState {
        case .success:
            return "checkmark.circle.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch viewModel.validationState {
        case .success:
            return .green
        default:
            return .red
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
}

#if os(iOS)
private typealias TextInputAutocapitalizationStyle = TextInputAutocapitalization
#else
private enum TextInputAutocapitalizationStyle {
    case never
    case words
}
#endif
