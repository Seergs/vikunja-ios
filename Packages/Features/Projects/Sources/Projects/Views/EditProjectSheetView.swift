import SwiftUI
import VikunjaCore
import VikuDesignSystem

/// Edit an existing project's title, color, and parent — the same shape as
/// `CreateProjectSheetView` (`NavigationStack` + inline title + toolbar
/// `Cancel`/`Save`, single content-sized detent).
public struct EditProjectSheetView: View {
    @Bindable var viewModel: EditProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var isShowingParentPicker = false

    private var detentHeight: CGFloat {
        viewModel.saveErrorMessage != nil ? Self.expandedHeight : Self.compactHeight
    }

    public init(viewModel: EditProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
                nameField

                colorSection

                parentProjectSection

                if let message = viewModel.saveErrorMessage {
                    SaveErrorBanner(message: message)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, VikunjaSpacing.md)
            .padding(.top, VikunjaSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.saveErrorMessage)
            .navigationTitle("Edit Project")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .fontWeight(.bold)
                            .disabled(!viewModel.canSave)
                    }
                }
            }
        }
        .presentationDetents([.height(detentHeight)])
        .presentationCornerRadius(VikunjaRadius.lg + VikunjaSpacing.sm)
        .sheet(isPresented: $isShowingParentPicker) {
            ProjectPickerSheet(
                title: "Parent Project",
                projects: viewModel.projects,
                selectedProjectID: viewModel.parentProjectID,
                showsNoneOption: true,
                excludingSubtreeOf: viewModel.editingProjectID,
            ) { project in
                viewModel.parentProjectID = project?.id
            }
        }
        .task {
            isTitleFocused = true
            await viewModel.load()
        }
    }

    private var nameField: some View {
        HStack(spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            Circle()
                .fill(Color(vikunjaHex: viewModel.hexColor) ?? VikunjaColor.brandPrimary)
                .frame(width: 10, height: 10)

            TextField("Project name", text: $viewModel.title)
                .font(VikunjaFont.body)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit(save)
        }
        .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
        .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            FieldLabel("Color")
            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(Self.colorSwatches, id: \.self) { swatch in
                    let swatchColor = Color(vikunjaHex: swatch) ?? VikunjaColor.brandPrimary
                    Circle()
                        .fill(swatchColor)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if swatch == viewModel.hexColor {
                                Circle()
                                    .strokeBorder(swatchColor.opacity(0.35), lineWidth: 3)
                                    .padding(-4)
                            }
                        }
                        .onTapGesture { viewModel.hexColor = swatch }
                }
            }
        }
    }

    private var parentProjectSection: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            FieldLabel("Parent Project")
            ParentProjectField(project: viewModel.selectedParentProject) {
                isShowingParentPicker = true
            }
        }
    }

    private func save() {
        guard viewModel.canSave else { return }
        Task {
            if await viewModel.save() != nil {
                dismiss()
            }
        }
    }

    private static let compactHeight: CGFloat = 300
    private static let expandedHeight: CGFloat = 366
    private static let colorSwatches = VikunjaColor.SwatchPalette.swatches
}

private struct ParentProjectField: View {
    let project: Project?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.sm) {
                if let project {
                    ProjectPickerIcon(hexColor: project.hexColor)
                    Text(project.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary)
                } else {
                    Text("None")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VikunjaColor.textTertiary)
            }
            .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xs)
            .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SaveErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(VikunjaColor.Semantic.dangerText)
            Text(message)
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(VikunjaColor.Semantic.dangerText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VikunjaColor.Semantic.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
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
