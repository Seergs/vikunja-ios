import SwiftUI
import VikuDesignSystem
import VikunjaCore

// The small building blocks shared by the compact task sheets
// (`QuickAddSheetView`, `DuplicateTaskSheetView`) so the two stay visually
// identical — a field-group label, the collapsed "Project" row that opens a
// picker, the priority chip row, and the save-error banner. Extracted here
// rather than duplicated per sheet.

/// A field-group caption ("Project", "Priority", ...).
struct FieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(VikuFont.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(VikuColor.textSecondary)
    }
}

/// The collapsed "Project" row: shows the current selection (or a
/// placeholder when none is chosen yet) and runs `action` — typically
/// opening a `ProjectPickerSheet` — on tap.
struct ProjectField: View {
    let project: Project?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikuSpacing.sm) {
                if let project {
                    ProjectPickerIcon(hexColor: project.hexColor)
                    Text(project.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary)
                } else {
                    Text("Choose project")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VikuColor.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VikuColor.textTertiary)
            }
            .padding(.horizontal, VikuSpacing.md - VikuSpacing.xxs)
            .padding(.vertical, VikuSpacing.sm + VikuSpacing.xs)
            .background(VikuColor.Surface.field, in: RoundedRectangle(cornerRadius: VikuRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PriorityOption: Identifiable {
    let priority: VikunjaTask.Priority
    let label: String
    let color: Color

    var id: VikunjaTask.Priority {
        priority
    }

    /// The four pickable priorities shown as chips (the sheets don't offer
    /// `.unset`/`.doNow`).
    static let all: [PriorityOption] = [
        PriorityOption(priority: .low, label: "Low", color: VikuColor.Priority.low),
        PriorityOption(priority: .medium, label: "Medium", color: VikuColor.Priority.medium),
        PriorityOption(priority: .high, label: "High", color: VikuColor.Priority.high),
        PriorityOption(priority: .urgent, label: "Urgent", color: VikuColor.Priority.urgent),
    ]
}

/// The horizontal priority chip row. `selection` is a binding so tapping the
/// active chip clears it back to `.unset`.
struct PriorityChipRow: View {
    @Binding var selection: VikunjaTask.Priority

    var body: some View {
        VStack(alignment: .leading, spacing: VikuSpacing.sm - VikuSpacing.xxs) {
            FieldLabel("Priority")
            HStack(spacing: VikuSpacing.sm) {
                ForEach(PriorityOption.all) { option in
                    PriorityChip(option: option, isSelected: selection == option.priority) {
                        selection = selection == option.priority ? .unset : option.priority
                    }
                }
            }
        }
    }
}

private struct PriorityChip: View {
    let option: PriorityOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikuSpacing.xs) {
                Image(systemName: "flag")
                    .font(.system(size: 11))
                Text(option.label)
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(isSelected ? option.color : VikuColor.textTertiary)
            .padding(.horizontal, VikuSpacing.sm + VikuSpacing.xs)
            .padding(.vertical, VikuSpacing.xs + VikuSpacing.xxs)
            .background(
                Capsule().fill(isSelected ? option.color.opacity(0.14) : VikuColor.Surface.field),
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? option.color : Color.clear, lineWidth: 1.5),
            )
        }
        .buttonStyle(.plain)
    }
}

/// Same tinted-card language as `TaskDetailView`'s `BlockedBanner` — a red
/// card rather than plain inline text, so a save failure reads as clearly as
/// every other error state in the app.
struct SaveErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: VikuSpacing.sm - VikuSpacing.xxs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(VikuColor.Semantic.dangerText)
            Text(message)
                .font(VikuFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(VikuColor.Semantic.dangerText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VikuSpacing.md - VikuSpacing.xxs)
        .padding(.vertical, VikuSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            VikuColor.Semantic.danger.opacity(0.12),
            in: RoundedRectangle(cornerRadius: VikuRadius.sm, style: .continuous),
        )
    }
}
