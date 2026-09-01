import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// The quick-add sheet opened from the tab bar's floating action button:
/// title + project + priority only, matching the design mockup's
/// `AddTaskSheet` (no due date/labels/assignee yet — see
/// `QuickAddTaskViewModel`'s doc comment). A compact bottom sheet: a
/// `NavigationStack` with an inline title and `Cancel`/`Save` in the toolbar
/// (the system pins that bar to the top of the sheet, so it can't drift when
/// the keyboard opens and nudges the sheet to its taller detent), switching
/// between two fixed `presentationDetents` heights (see `compactHeight`/
/// `expandedHeight`) so it only grows when the error banner needs the room.
/// Content is anchored to the top rather than centered, so the extra space at
/// the taller detent pools below the fields instead of above the title.
/// Presented as a plain `.sheet` by whichever screen owns the FAB.
public struct QuickAddSheetView: View {
    @Bindable var viewModel: QuickAddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingProjectPicker = false
    @FocusState private var isTitleFocused: Bool

    /// A single detent sized to the current content, not a two-detent set:
    /// when a sheet offers more than one detent and the keyboard appears,
    /// iOS jumps it to the *largest* one — which left a big gap between the
    /// priority chips and the keyboard. One height, grown only when the
    /// error banner needs the room, keeps the sheet exactly as tall as its
    /// content.
    private var detentHeight: CGFloat {
        viewModel.saveErrorMessage != nil ? Self.expandedHeight : Self.compactHeight
    }

    public init(viewModel: QuickAddTaskViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
                TextField("Task title", text: $viewModel.title)
                    .font(VikunjaFont.body)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
                    .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
                    .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))

                projectSection

                prioritySection

                if let message = viewModel.saveErrorMessage {
                    SaveErrorBanner(message: message)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, VikunjaSpacing.md)
            .padding(.top, VikunjaSpacing.md)
            // Anchored to the top: when the keyboard nudges the sheet up to
            // its taller detent, the slack falls below the priority chips
            // instead of being split above and below a vertically-centered
            // block (which pushed the title away from the toolbar).
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // A spring rather than `.easeInOut`: closer to the curve the
            // system itself uses to animate a sheet's own detent resize, so
            // our content's own transition doesn't visibly race against it.
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.saveErrorMessage)
            .navigationTitle("New Task")
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
                        Button("Save") {
                            Task {
                                if await viewModel.save() != nil {
                                    dismiss()
                                }
                            }
                        }
                        .fontWeight(.bold)
                        .disabled(!viewModel.canSave)
                    }
                }
            }
        }
        .presentationDetents([.height(detentHeight)])
        .presentationCornerRadius(VikunjaRadius.lg + VikunjaSpacing.sm)
        .sheet(isPresented: $isShowingProjectPicker) {
            ProjectPickerSheet(
                title: "Choose Project",
                projects: viewModel.projects,
                selectedProjectID: viewModel.selectedProjectID,
            ) { project in
                viewModel.selectedProjectID = project?.id
            }
        }
        .task {
            isTitleFocused = true
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        switch viewModel.loadState {
        case let .failure(message):
            Text(message)
                .font(VikunjaFont.footnote)
                .foregroundStyle(VikunjaColor.textSecondary)
        case .loading, .idle:
            ProgressView()
        case .loaded:
            VStack(alignment: .leading, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
                FieldLabel("Project")
                ProjectField(project: viewModel.selectedProject) {
                    isShowingProjectPicker = true
                }
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            FieldLabel("Priority")
            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(Self.priorityOptions, id: \.priority) { option in
                    PriorityChip(
                        option: option,
                        isSelected: viewModel.priority == option.priority,
                    ) {
                        viewModel.priority = viewModel.priority == option.priority ? .unset : option.priority
                    }
                }
            }
        }
    }

    /// Fixed, hand-measured heights rather than a live content measurement:
    /// a `.sheet` proposes its current detent's height back to its own
    /// content as a ceiling, so `GeometryReader`/`onGeometryChange`/
    /// `.fixedSize` just report that already-capped size back — a feedback
    /// loop that can never settle. `compactHeight` fits the title/project/
    /// priority rows above the keyboard with no slack; `expandedHeight` adds
    /// room for the error banner.
    private static let compactHeight: CGFloat = 300
    private static let expandedHeight: CGFloat = 366

    private static let priorityOptions: [PriorityOption] = [
        PriorityOption(priority: .low, label: "Low", color: VikunjaColor.Priority.low),
        PriorityOption(priority: .medium, label: "Medium", color: VikunjaColor.Priority.medium),
        PriorityOption(priority: .high, label: "High", color: VikunjaColor.Priority.high),
        PriorityOption(priority: .urgent, label: "Urgent", color: VikunjaColor.Priority.urgent),
    ]
}

/// Same tinted-card language as `TaskDetailView`'s `BlockedBanner` — a red
/// card rather than plain inline text, so a save failure reads as clearly as
/// every other error state in the app.
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

private struct PriorityOption {
    let priority: VikunjaTask.Priority
    let label: String
    let color: Color
}

/// The collapsed "Project" row: shows the current selection (or a
/// placeholder when none is chosen yet) and opens `ProjectPickerView` on tap
/// — replaces the earlier inline chip row now that the mockup opens a
/// dedicated picker sheet instead.
private struct ProjectField: View {
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
                    Text("Choose project")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VikunjaColor.textTertiary)
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

private struct PriorityChip: View {
    let option: PriorityOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.xs) {
                Image(systemName: "flag")
                    .font(.system(size: 11))
                Text(option.label)
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(isSelected ? option.color : VikunjaColor.textTertiary)
            .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xs)
            .padding(.vertical, VikunjaSpacing.xs + VikunjaSpacing.xxs)
            .background(
                Capsule().fill(isSelected ? option.color.opacity(0.14) : VikunjaColor.Surface.field),
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? option.color : Color.clear, lineWidth: 1.5),
            )
        }
        .buttonStyle(.plain)
    }
}
