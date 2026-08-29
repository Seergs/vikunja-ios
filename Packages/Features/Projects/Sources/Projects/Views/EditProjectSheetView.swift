import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

public struct EditProjectSheetView: View {
    @Bindable var viewModel: EditProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var isShowingParentPicker = false

    private var detent: Binding<PresentationDetent> {
        Binding(
            get: { .height(viewModel.saveErrorMessage != nil ? Self.expandedHeight : Self.compactHeight) },
            set: { _ in }
        )
    }

    public init(viewModel: EditProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
            header

            nameField

            colorSection

            parentProjectSection

            if let message = viewModel.saveErrorMessage {
                SaveErrorBanner(message: message)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, VikunjaSpacing.md)
        .padding(.top, VikunjaSpacing.sm)
        .padding(.bottom, VikunjaSpacing.lg)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.saveErrorMessage)
        .presentationDetents([.height(Self.compactHeight), .height(Self.expandedHeight)], selection: detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(VikunjaRadius.lg + VikunjaSpacing.sm)
        .sheet(isPresented: $isShowingParentPicker) {
            ParentProjectPickerView(groups: viewModel.projectGroups, selectedProjectID: $viewModel.parentProjectID)
        }
        .task {
            isTitleFocused = true
            await viewModel.load()
        }
    }

    private var header: some View {
        ZStack {
            Text("Edit Project")
                .font(VikunjaFont.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(VikunjaColor.textSecondary)

                Spacer()

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

    private static let compactHeight: CGFloat = 340
    private static let expandedHeight: CGFloat = 420
    private static let colorSwatches = VikunjaColor.SwatchPalette.swatches
}

private struct ParentProjectField: View {
    let project: Project?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.sm) {
                if let project {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary)
                        .frame(width: 8, height: 8)
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

private struct ParentProjectPickerView: View {
    let groups: [EditProjectViewModel.ProjectGroup]
    @Binding var selectedProjectID: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredGroups: [EditProjectViewModel.ProjectGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return groups }
        return groups.compactMap { group in
            let rootMatches = group.root.title.localizedCaseInsensitiveContains(trimmed)
            let matchingChildren = group.children.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
            guard rootMatches || !matchingChildren.isEmpty else { return nil }
            return EditProjectViewModel.ProjectGroup(root: group.root, children: rootMatches ? group.children : matchingChildren)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VikunjaSpacing.lg) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        NoneProjectRow(isSelected: selectedProjectID == nil) {
                            selectedProjectID = nil
                            dismiss()
                        }
                    }
                    ForEach(filteredGroups) { group in
                        VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                            ParentProjectPickerRow(
                                project: group.root,
                                isBold: true,
                                isSelected: selectedProjectID == group.root.id,
                                action: { select(group.root) }
                            )
                            ForEach(group.children) { child in
                                ParentProjectPickerRow(
                                    project: child,
                                    isBold: false,
                                    isSelected: selectedProjectID == child.id,
                                    action: { select(child) }
                                )
                                .padding(.leading, VikunjaSpacing.lg)
                            }
                        }
                    }
                }
                .padding(.vertical, VikunjaSpacing.sm)
            }
            .searchable(text: $query, prompt: "Search projects...")
            .navigationTitle("Parent Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }

    private func select(_ project: Project) {
        selectedProjectID = project.id
        dismiss()
    }
}

private struct NoneProjectRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.sm) {
                Circle()
                    .strokeBorder(VikunjaColor.textTertiary, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                Text("None")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VikunjaColor.brandPrimary)
                }
            }
            .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xs)
            .background(
                isSelected ? VikunjaColor.Surface.field : Color.clear,
                in: RoundedRectangle(cornerRadius: VikunjaRadius.sm - VikunjaSpacing.xxs, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, VikunjaSpacing.sm)
    }
}

private struct ParentProjectPickerRow: View {
    let project: Project
    let isBold: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.sm) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary)
                    .frame(width: 8, height: 8)
                Text(project.title)
                    .font(.system(size: 15, weight: isBold ? .semibold : .regular))
                    .foregroundStyle(Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VikunjaColor.brandPrimary)
                }
            }
            .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xs)
            .background(
                isSelected ? VikunjaColor.Surface.field : Color.clear,
                in: RoundedRectangle(cornerRadius: VikunjaRadius.sm - VikunjaSpacing.xxs, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, VikunjaSpacing.sm)
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

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(VikunjaFont.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(VikunjaColor.textSecondary)
    }
}
