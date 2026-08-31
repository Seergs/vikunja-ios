import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// The compact "new label" / "edit label" sheet: a title field and a row of
/// preset color swatches from `VikunjaColor.SwatchPalette` — no free-form
/// color picker, matching how projects choose their color. A plain bottom
/// sheet with no `NavigationStack`, following `Projects`' `CreateProjectSheetView`.
struct LabelEditorSheet: View {
    let mode: LabelEditorMode
    /// Passed the trimmed title and the picked hex; the caller performs the
    /// create/update against the view model.
    let onSave: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var title: String
    @State private var hexColor: String
    @State private var isSaving = false

    init(mode: LabelEditorMode, onSave: @escaping (String, String) async -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _hexColor = State(initialValue: VikunjaColor.SwatchPalette.swatches[0])
        case let .edit(label):
            _title = State(initialValue: label.title)
            _hexColor = State(initialValue: label.hexColor)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
            header
            nameField
            colorSection
        }
        .padding(.horizontal, VikunjaSpacing.md)
        .padding(.top, VikunjaSpacing.sm)
        .padding(.bottom, VikunjaSpacing.lg)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(VikunjaRadius.lg + VikunjaSpacing.sm)
        .task { isTitleFocused = true }
    }

    private var header: some View {
        ZStack {
            Text(mode.isEdit ? "Edit Label" : "New Label")
                .font(VikunjaFont.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(VikunjaColor.textSecondary)

                Spacer()

                if isSaving {
                    ProgressView()
                } else {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var nameField: some View {
        HStack(spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            Circle()
                .fill(Color(vikunjaHex: hexColor) ?? VikunjaColor.brandPrimary)
                .frame(width: 10, height: 10)

            TextField("Label name", text: $title)
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
            Text("Color")
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(VikunjaColor.textSecondary)

            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(VikunjaColor.SwatchPalette.swatches, id: \.self) { swatch in
                    let swatchColor = Color(vikunjaHex: swatch) ?? VikunjaColor.brandPrimary
                    Circle()
                        .fill(swatchColor)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if swatch == hexColor {
                                Circle()
                                    .strokeBorder(swatchColor.opacity(0.35), lineWidth: 3)
                                    .padding(-4)
                            }
                        }
                        .onTapGesture { hexColor = swatch }
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = hexColor
        isSaving = true
        Task {
            await onSave(trimmed, color)
            isSaving = false
            dismiss()
        }
    }
}

private extension LabelEditorMode {
    var isEdit: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}
