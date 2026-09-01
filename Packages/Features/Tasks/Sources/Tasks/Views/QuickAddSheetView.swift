import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// The quick-add sheet opened from the tab bar's floating action button:
/// title + project + priority only, matching the design mockup's
/// `AddTaskSheet` (no due date/labels/assignee yet — see
/// `QuickAddTaskViewModel`'s doc comment). A compact bottom sheet rather than
/// a full-height one — no `NavigationStack`/toolbar, since those force the
/// system to take over the whole screen; it switches between two fixed
/// `presentationDetents` heights (see `compactHeight`/`expandedHeight`) so it
/// only grows when the error banner needs the extra room. Presented as a
/// plain `.sheet` by
/// whichever screen owns the FAB — this package owns no `NavigationStack`/
/// `Router` of its own, the same exception `TaskDetailView` makes for a leaf
/// screen with no push navigation of its own.
public struct QuickAddSheetView: View {
    @Bindable var viewModel: QuickAddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingProjectPicker = false

    /// Derived straight from `viewModel.saveErrorMessage` rather than mirrored
    /// into its own `@State` updated separately (via `onChange`): that split
    /// used to produce two independent animation transactions — one for the
    /// banner's own `.transition`, one for the detent switch — that raced
    /// each other and looked like a position "reset" before the real grow
    /// animation kicked in. Reading both off the same value under one
    /// `.animation(_:value:)` keeps them in the same transaction.
    private var detent: Binding<PresentationDetent> {
        Binding(
            get: { .height(viewModel.saveErrorMessage != nil ? Self.expandedHeight : Self.compactHeight) },
            set: { _ in },
        )
    }

    public init(viewModel: QuickAddTaskViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
            header

            TextField("Task title", text: $viewModel.title)
                .font(VikunjaFont.body)
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
        .padding(.top, VikunjaSpacing.sm)
        .padding(.bottom, VikunjaSpacing.lg)
        // A spring rather than `.easeInOut`: closer to the curve the system
        // itself uses to animate a sheet's own detent resize, so our
        // content's own transition doesn't visibly race against it.
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.saveErrorMessage)
        // Both heights declared upfront, not just the current one: SwiftUI
        // only animates a detent transition when `selection` switches
        // between options already present in the set — redefining the set's
        // sole member each time is treated as a structural change and just
        // snaps instead of animating.
        .presentationDetents([.height(Self.compactHeight), .height(Self.expandedHeight)], selection: detent)
        .presentationDragIndicator(.visible)
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
        .task { await viewModel.load() }
    }

    private var header: some View {
        ZStack {
            Text("New Task")
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

    /// Two fixed, hand-measured heights rather than a live content
    /// measurement: a `.sheet` proposes its *current* detent's height back
    /// to its own content as a ceiling, so anything that tries to measure
    /// "how tall do I actually want to be" (`GeometryReader`,
    /// `onGeometryChange`, `.fixedSize`) just reports that already-capped
    /// size back — a feedback loop that can never grow past whatever height
    /// the sheet started at (confirmed the hard way: the banner's text kept
    /// truncating instead of driving a resize). Two known-good constants,
    /// switched by `viewModel.saveErrorMessage`'s presence, sidestep that
    /// entirely.
    private static let compactHeight: CGFloat = 320
    private static let expandedHeight: CGFloat = 400

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
