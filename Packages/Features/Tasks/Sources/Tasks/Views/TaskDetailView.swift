import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// A single task's detail screen: completion, due date, priority, labels,
/// subtasks, and dependencies. Pushed as a leaf screen inside whichever
/// feature's `NavigationStack` opened it (Projects, today) — this package
/// owns no `NavigationStack`/`Router` of its own.
public struct TaskDetailView: View {
    @Bindable var viewModel: TaskDetailViewModel
    /// Type-erased, like `Features/Projects`' and `Features/Home`'s own
    /// `taskDetailDestination` closures — this package can't import
    /// `Projects` directly, so `AppContainer` supplies the actual
    /// `ProjectOverviewRootView` to push when the project pill is tapped.
    private let projectDestination: (Project) -> AnyView
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDueDatePicker = false
    @State private var isShowingLabelPicker = false
    @State private var isShowingMovePicker = false
    @State private var isShowingDeleteConfirmation = false
    @State private var relationSheetStep: RelationSheetStep?
    @State private var relatedTaskDestination: RelatedTaskDestination?
    @State private var projectDestinationBox: ProjectDestinationBox?
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @State private var isEditingDescription = false
    @State private var descriptionDraft = ""
    @FocusState private var focusedField: EditableField?

    private enum EditableField: Hashable {
        case title
        case description
    }

    public init(viewModel: TaskDetailViewModel, projectDestination: @escaping (Project) -> AnyView) {
        self.viewModel = viewModel
        self.projectDestination = projectDestination
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch viewModel.loadState {
                case .failure(let message):
                    TaskDetailStatusView(message: message) {
                        Task { await viewModel.load() }
                    }
                    .padding(.top, VikunjaSpacing.xxl)
                default:
                    loadedContent
                }
            }
            .padding(.horizontal, VikunjaSpacing.md)
            .padding(.bottom, VikunjaSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VikunjaColor.Surface.page)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .scrollDismissesKeyboard(.interactively)
        // The tap-outside/scroll dismissal above isn't reliable on a physical
        // device once the keyboard is up (a background tap there commonly
        // resigns the keyboard through UIKit without SwiftUI's gesture ever
        // firing) — a checkmark in the nav bar, matching Notes/Reminders, is
        // the dependable way to commit the description edit. The title field
        // doesn't need it: it's single-line, so its own Return key already
        // submits.
        .toolbar {
            if focusedField == .description {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Move to Project", systemImage: "folder") {
                        isShowingMovePicker = true
                    }
                    // `role: .destructive` alone renders blue here, not red:
                    // the tab bar's `.tint(VikunjaColor.brandPrimary)` leaks
                    // into this menu and overrides the role's tint — mirrors
                    // `ProjectTaskRow`'s context menu in `Features/Projects`.
                    Button("Delete Task", systemImage: "trash", role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                    .tint(VikunjaColor.Semantic.danger)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationTitle("Task Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.load() }
        .task { await viewModel.loadComments() }
        .refreshable {
            await viewModel.load()
            await viewModel.loadComments()
        }
        .sheet(isPresented: $isShowingDueDatePicker) {
            DueDatePickerSheet(initialDate: viewModel.task.dueDate) { newDate in
                Task { await viewModel.setDueDate(newDate) }
            }
        }
        .sheet(isPresented: $isShowingLabelPicker) {
            LabelPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingMovePicker) {
            MoveProjectPickerSheet(viewModel: viewModel) { project in
                Task {
                    if await viewModel.move(to: project) {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            "This permanently deletes the task.",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Task", role: .destructive) {
                Task {
                    if await viewModel.deleteTask() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $relationSheetStep) { step in
            switch step {
            case .pickKind:
                RelationKindPickerSheet { kind in
                    relationSheetStep = .pickTask(kind)
                }
            case .pickTask(let kind):
                RelationTaskPickerSheet(viewModel: viewModel, kind: kind) { candidate in
                    let relation = TaskRelation(id: candidate.id, title: candidate.title, isDone: candidate.isDone, projectID: candidate.projectID)
                    Task { await viewModel.addRelation(relation, kind: kind) }
                    relationSheetStep = nil
                }
            }
        }
        .navigationDestination(item: $relatedTaskDestination) { destination in
            TaskDetailView(
                viewModel: viewModel.makeDetailViewModel(task: destination.task, project: destination.project),
                projectDestination: projectDestination
            )
        }
        // The `AnyView` is built once, at tap time, and stashed in
        // `projectDestinationBox` rather than called fresh inside this
        // closure — see `ProjectDestinationBox`'s doc comment for why that
        // distinction matters here.
        .navigationDestination(item: $projectDestinationBox) { box in
            box.content
        }
        .onChange(of: focusedField) { previous, current in
            if previous == .title, current != .title { commitTitleEdit() }
            if previous == .description, current != .description { commitDescriptionEdit() }
        }
    }

    private func beginEditingTitle() {
        titleDraft = viewModel.task.title
        isEditingTitle = true
        focusedField = .title
    }

    private func commitTitleEdit() {
        isEditingTitle = false
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != viewModel.task.title else { return }
        Task { await viewModel.setTitle(trimmed) }
    }

    private func beginEditingDescription() {
        descriptionDraft = viewModel.task.description ?? ""
        isEditingDescription = true
        focusedField = .description
    }

    private func commitDescriptionEdit() {
        isEditingDescription = false
        let trimmed = descriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDescription = trimmed.isEmpty ? nil : trimmed
        guard newDescription != viewModel.task.description else { return }
        Task { await viewModel.setDescription(newDescription) }
    }

    private func openRelation(_ relation: TaskRelation) {
        Task {
            if let (task, project) = await viewModel.loadRelatedTask(relation) {
                relatedTaskDestination = RelatedTaskDestination(task: task, project: project)
            }
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        let task = viewModel.task
        let project = viewModel.project

        Button {
            projectDestinationBox = ProjectDestinationBox(id: project.id, content: projectDestination(project))
        } label: {
            ProjectPill(project: project)
        }
        .buttonStyle(.plain)
        .padding(.top, VikunjaSpacing.sm)

        HStack(alignment: .top, spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
            Button {
                Task { await viewModel.toggleDone() }
            } label: {
                TaskDetailCheckbox(isDone: task.isDone, color: swatchColor(project))
            }
            .buttonStyle(.plain)
            .padding(.top, VikunjaSpacing.xxs)

            if isEditingTitle {
                // Single-line (no `axis:`) so Return submits via `onSubmit`
                // instead of inserting a line break — a task title shouldn't
                // wrap across lines anyway.
                TextField("Task title", text: $titleDraft)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            } else {
                Text(task.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .strikethrough(task.isDone)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditingTitle() }
            }
        }
        .padding(.top, VikunjaSpacing.sm)

        if task.isBlocked {
            BlockedBanner(waitingOn: task.dependsOn.filter { !$0.isDone }.count)
                .padding(.top, VikunjaSpacing.md)
        }

        if isEditingDescription {
            // Multi-line (`axis: .vertical`) so it grows with the text and
            // Return inserts a line break, matching a description's normal
            // multi-paragraph use — unlike the title, there's no `onSubmit`
            // here since a multi-line field never submits on Return. Committing
            // happens via the nav bar checkmark below, or by tapping
            // elsewhere (see `focusedField`'s `onChange` above).
            TextField("Add description...", text: $descriptionDraft, axis: .vertical)
                .font(VikunjaFont.callout)
                .foregroundStyle(VikunjaColor.textSecondary)
                .focused($focusedField, equals: .description)
                .padding(.top, VikunjaSpacing.md)
        } else if let description = task.description, !description.isEmpty {
            Text(description)
                .font(VikunjaFont.callout)
                .foregroundStyle(VikunjaColor.textSecondary)
                .contentShape(Rectangle())
                .onTapGesture { beginEditingDescription() }
                .padding(.top, VikunjaSpacing.md)
        } else {
            Text("Add description...")
                .font(VikunjaFont.callout)
                .foregroundStyle(VikunjaColor.textTertiary)
                .contentShape(Rectangle())
                .onTapGesture { beginEditingDescription() }
                .padding(.top, VikunjaSpacing.md)
        }

        VStack(alignment: .leading, spacing: VikunjaSpacing.sm) {
            Button {
                isShowingDueDatePicker = true
            } label: {
                InfoRow(
                    systemImage: "calendar",
                    iconColor: task.dueDate == nil ? VikunjaColor.textTertiary : VikunjaColor.textSecondary,
                    title: "Due",
                    value: task.dueDate.map(TaskDueDateFormatter.string(for:)) ?? "Set due date",
                    valueColor: task.dueDate == nil ? VikunjaColor.textTertiary : (isOverdue(task) ? VikunjaColor.Semantic.dangerText : nil),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(VikunjaTask.Priority.allCases.filter { $0 != .doNow }, id: \.self) { priority in
                    Button {
                        Task { await viewModel.setPriority(priority) }
                    } label: {
                        HStack {
                            Text(priorityMenuLabel(priority))
                            if task.priority == priority {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                InfoRow(
                    systemImage: "flag",
                    iconColor: priorityDisplay(task.priority)?.color ?? VikunjaColor.textTertiary,
                    title: "Priority",
                    value: priorityDisplay(task.priority)?.label ?? "Set priority",
                    valueColor: priorityDisplay(task.priority)?.color ?? VikunjaColor.textTertiary,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, VikunjaSpacing.lg)

        SectionBlock(title: "Labels", trailing: AnyView(EditLabelsButton { isShowingLabelPicker = true })) {
            if task.labels.isEmpty {
                Button("Add labels…") {
                    isShowingLabelPicker = true
                }
                .buttonStyle(.plain)
                .font(VikunjaFont.subheadline)
                .foregroundStyle(VikunjaColor.textTertiary)
            } else {
                LabelsWrap(labels: task.labels)
            }
        }

        if !task.subtasks.isEmpty {
            SectionBlock(title: "Subtasks", count: "\(task.subtasks.filter(\.isDone).count)/\(task.subtasks.count)") {
                SubtasksCard(subtasks: task.subtasks, color: swatchColor(project))
            }
        }

        SectionBlock(title: "Relations", trailing: AnyView(AddRelationButton { relationSheetStep = .pickKind })) {
            let groups = relationGroups(for: task)
            if groups.isEmpty {
                Text("No relations with other tasks.")
                    .font(VikunjaFont.subheadline)
                    .foregroundStyle(VikunjaColor.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
                    ForEach(groups, id: \.kind) { group in
                        RelationGroupView(
                            kind: group.kind,
                            relations: group.relations,
                            projectTitle: projectTitle(for:),
                            onTap: openRelation,
                            onRemove: { relation in
                                Task { await viewModel.removeRelation(relation, kind: group.kind) }
                            }
                        )
                    }
                }
            }
        }

        SectionBlock(title: "Comments", count: viewModel.comments.isEmpty ? nil : "\(viewModel.comments.count)") {
            CommentsSection(
                comments: viewModel.comments,
                loadState: viewModel.commentsLoadState,
                onSubmit: { text in
                    Task { await viewModel.addComment(text) }
                }
            )
        }
    }

    /// `Depends on` and `Blocks` grouped alongside every `otherRelations`
    /// kind under one umbrella "Relations" section (matching the design
    /// mockup's combined "Relaciones" section) — `Subtasks` stays its own
    /// section above since it renders as a checklist, not a relation list.
    private func relationGroups(for task: VikunjaTask) -> [(kind: RelationKind, relations: [TaskRelation])] {
        var groups: [(kind: RelationKind, relations: [TaskRelation])] = []
        if !task.dependsOn.isEmpty { groups.append((.blocked, task.dependsOn)) }
        if !task.blocks.isEmpty { groups.append((.blocking, task.blocks)) }
        groups.append(contentsOf: orderedOtherRelations(task))
        return groups
    }

    /// `task.otherRelations` is a dictionary — iterate `RelationKind.allCases`
    /// instead of the dictionary directly so section order stays stable
    /// across renders rather than following Swift's unordered `Dictionary`
    /// iteration.
    private func orderedOtherRelations(_ task: VikunjaTask) -> [(kind: RelationKind, relations: [TaskRelation])] {
        RelationKind.allCases.compactMap { kind in
            guard let relations = task.otherRelations[kind], !relations.isEmpty else { return nil }
            return (kind, relations)
        }
    }

    /// `TaskRelation` only carries a `projectID` (not a title, since a
    /// related task can live in any project and this screen doesn't have a
    /// project repository to resolve arbitrary ones) — this only resolves
    /// the name when the relation happens to sit in this task's own project,
    /// which covers subtasks and same-project dependencies without risking a
    /// wrong or fabricated name for the rest.
    private func projectTitle(for relation: TaskRelation) -> String? {
        relation.projectID == viewModel.project.id ? viewModel.project.title : nil
    }

    private func isOverdue(_ task: VikunjaTask) -> Bool {
        guard let dueDate = task.dueDate, !task.isDone else { return false }
        return dueDate < Date()
    }

    private func swatchColor(_ project: Project) -> Color {
        Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary
    }

    private struct PriorityDisplay {
        let label: String
        let color: Color
    }

    private func priorityDisplay(_ priority: VikunjaTask.Priority) -> PriorityDisplay? {
        switch priority {
        case .unset: return nil
        case .low: return PriorityDisplay(label: "Low", color: VikunjaColor.Priority.low)
        case .medium: return PriorityDisplay(label: "Medium", color: VikunjaColor.Priority.medium)
        case .high: return PriorityDisplay(label: "High", color: VikunjaColor.Priority.high)
        case .urgent, .doNow: return PriorityDisplay(label: "Urgent", color: VikunjaColor.Priority.urgent)
        }
    }

    private func priorityMenuLabel(_ priority: VikunjaTask.Priority) -> String {
        priorityDisplay(priority)?.label ?? "None"
    }
}

private struct ProjectPill: View {
    let project: Project

    private var swatchColor: Color {
        Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.xs + VikunjaSpacing.xxs) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(swatchColor)
                .frame(width: 10, height: 10)
            Text(project.title)
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(VikunjaColor.textSecondary)
        }
    }
}

private struct TaskDetailCheckbox: View {
    let isDone: Bool
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Circle()
            .strokeBorder(isDone ? Color.clear : color, lineWidth: 2)
            .background(Circle().fill(isDone ? color : Color.clear))
            .frame(width: size, height: size)
            .overlay {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}

private struct BlockedBanner: View {
    let waitingOn: Int

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            Image(systemName: "link")
                .font(.system(size: 11))
                .foregroundStyle(VikunjaColor.Semantic.dangerText)
            Text("Blocked · waiting on \(waitingOn) task\(waitingOn == 1 ? "" : "s")")
                .font(VikunjaFont.footnote)
                .fontWeight(.bold)
                .foregroundStyle(VikunjaColor.Semantic.dangerText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VikunjaColor.Semantic.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }
}

private struct InfoRow: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let value: String
    var valueColor: Color?
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 18)
            Text(title)
                .font(VikunjaFont.subheadline)
                .foregroundStyle(Color.primary)
            Spacer()
            Text(value)
                .font(VikunjaFont.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor ?? Color.primary)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VikunjaColor.textTertiary)
            }
        }
        .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xxs)
        .background(VikunjaColor.Surface.card, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }
}

private struct SectionBlock<Content: View>: View {
    let title: String
    var count: String?
    var trailing: AnyView = AnyView(EmptyView())
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm) {
            HStack(spacing: VikunjaSpacing.xs) {
                Text(title)
                    .fontWeight(.bold)
                if let count {
                    Text(count)
                        .fontWeight(.regular)
                }
                Spacer(minLength: 0)
                trailing
            }
            .font(VikunjaFont.footnote)
            .foregroundStyle(VikunjaColor.textSecondary)
            .textCase(.uppercase)
            .kerning(0.3)

            content
        }
        .padding(.top, VikunjaSpacing.xl)
    }
}

/// The "+ Edit" affordance next to the Labels section header — always
/// present, per the mockup, whether or not the task already has labels.
private struct EditLabelsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.xxs) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Edit")
            }
            .foregroundStyle(VikunjaColor.brandPrimary)
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }
}

private struct LabelsWrap: View {
    let labels: [VikunjaCore.Label]

    var body: some View {
        FlowLayout(spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            ForEach(labels) { label in
                LabelPill(label: label)
            }
        }
    }
}

private struct LabelPill: View {
    let label: VikunjaCore.Label

    private var color: Color {
        Color(vikunjaHex: label.hexColor) ?? VikunjaColor.textSecondary
    }

    var body: some View {
        Text(label.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.xxs)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

/// Simple wrapping row layout for labels — SwiftUI has no built-in flow
/// layout, and labels can't be forced onto a single scrollable row here the
/// way `ProjectOverviewView`'s filter chips are.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Read-only for now: a `TaskRelation` is a thin summary (see its doc
/// comment), not enough to safely round-trip through
/// `TaskRepositoryProtocol.update(_:)` without first fetching the full task —
/// an extra request per row this screen doesn't make yet.
private struct SubtasksCard: View {
    let subtasks: [TaskRelation]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
                if index > 0 {
                    Divider().padding(.leading, VikunjaSpacing.md - VikunjaSpacing.xxs)
                }
                HStack(spacing: VikunjaSpacing.sm) {
                    TaskDetailCheckbox(isDone: subtask.isDone, color: color, size: 20)
                    Text(subtask.title)
                        .font(VikunjaFont.subheadline)
                        .foregroundStyle(subtask.isDone ? VikunjaColor.textTertiary : Color.primary)
                        .strikethrough(subtask.isDone)
                    Spacer()
                }
                .padding(.horizontal, VikunjaSpacing.md - VikunjaSpacing.xxs)
                .padding(.vertical, VikunjaSpacing.sm + VikunjaSpacing.xs)
            }
        }
        .background(VikunjaColor.Surface.card, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }
}

/// One relation kind and its rows. When a kind carries more than
/// `collapseThreshold` relations the list starts collapsed to the first few,
/// with a "Show N more"/"Show less" toggle — long relation lists (a task that
/// blocks a dozen others) otherwise push the rest of the screen far down.
private struct RelationGroupView: View {
    let kind: RelationKind
    let relations: [TaskRelation]
    let projectTitle: (TaskRelation) -> String?
    let onTap: (TaskRelation) -> Void
    let onRemove: (TaskRelation) -> Void

    @State private var isExpanded = false

    private static let collapseThreshold = 3

    private var isCollapsible: Bool {
        relations.count > Self.collapseThreshold
    }

    private var visibleRelations: ArraySlice<TaskRelation> {
        isCollapsible && !isExpanded ? relations.prefix(Self.collapseThreshold) : relations[...]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.xs) {
            Text(kind.displayName)
                .font(VikunjaFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(VikunjaColor.textTertiary)
            VStack(spacing: VikunjaSpacing.sm) {
                ForEach(visibleRelations) { relation in
                    DependencyRow(
                        relation: relation,
                        projectTitle: projectTitle(relation),
                        onTap: { onTap(relation) },
                        onRemove: { onRemove(relation) }
                    )
                }
            }
            if isCollapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: VikunjaSpacing.xxs) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                        Text(isExpanded
                             ? "Show less"
                             : "Show \(relations.count - Self.collapseThreshold) more")
                    }
                    .font(VikunjaFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(VikunjaColor.brandPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, VikunjaSpacing.xxs)
            }
        }
    }
}

private struct DependencyRow: View {
    let relation: TaskRelation
    let projectTitle: String?
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm) {
            Button(action: onTap) {
                HStack(spacing: VikunjaSpacing.sm) {
                    Circle()
                        .strokeBorder(relation.isDone ? Color.clear : VikunjaColor.textTertiary, lineWidth: 2)
                        .background(Circle().fill(relation.isDone ? VikunjaColor.Semantic.success : Color.clear))
                        .frame(width: 20, height: 20)
                        .overlay {
                            if relation.isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                    VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                        Text(relation.title)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.primary)
                            .strikethrough(relation.isDone)
                        if let projectTitle {
                            Text(projectTitle)
                                .font(VikunjaFont.caption)
                                .foregroundStyle(VikunjaColor.textTertiary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VikunjaColor.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(VikunjaColor.Surface.field, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm)
        .background(VikunjaColor.Surface.card, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
    }
}

/// Identifies which related task's detail screen to push, resolved
/// asynchronously via `TaskDetailViewModel.loadRelatedTask(_:)` when a
/// `DependencyRow` is tapped.
private struct RelatedTaskDestination: Identifiable, Hashable {
    let task: VikunjaTask
    let project: Project

    var id: Int { task.id }
}

/// Wraps the type-erased `AnyView` `projectDestination(_:)` builds, computed
/// once at tap time rather than inside the `.navigationDestination(item:)`
/// closure itself. That closure re-runs on every re-render of this screen —
/// unlike `.navigationDestination(for:)`, which keys off a stable value
/// already sitting in the `NavigationPath` and only rebuilds when the path
/// actually changes — and `AnyView` erases the type identity SwiftUI would
/// otherwise use to recognize "this is still the same destination" across
/// those reruns. Rebuilding the `AnyView` (and the `ProjectOverviewViewModel`
/// inside it) fresh each time meant the pushed screen kept getting torn down
/// and remounted from scratch, restarting its `.task { load() }` before it
/// ever finished — an endless-looking spinner. Building it once here and
/// handing the closure the same cached value every time avoids that; the
/// concrete-typed `relatedTaskDestination` above doesn't need this same
/// treatment since it pushes a real `TaskDetailView`, not an `AnyView`.
private struct ProjectDestinationBox: Identifiable, Hashable {
    let id: Int
    let content: AnyView

    // Written by hand: `AnyView` isn't `Hashable`, and identity here only
    // ever needs to key off `id` anyway.
    static func == (lhs: ProjectDestinationBox, rhs: ProjectDestinationBox) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// The "+ Add" affordance next to the Relations section header.
private struct AddRelationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.xxs) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Add")
            }
            .foregroundStyle(VikunjaColor.brandPrimary)
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }
}

/// The two steps of adding a relation, matching the design mockup: first
/// pick a relation kind, then pick the other task. Modeled as one
/// `Identifiable` enum (rather than two independent `Bool`s) so exactly one
/// sheet is ever presented at a time and picking a kind can hand off
/// straight into the task picker.
private enum RelationSheetStep: Identifiable {
    case pickKind
    case pickTask(RelationKind)

    var id: String {
        switch self {
        case .pickKind: return "pickKind"
        case .pickTask(let kind): return "pickTask-\(kind.rawValue)"
        }
    }
}

/// Lets the user choose which kind of relation to add — every `RelationKind`
/// except `subtask`/`parenttask`, which are represented on this screen
/// through the (read-only, for now) Subtasks checklist instead.
private struct RelationKindPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (RelationKind) -> Void

    private var kinds: [RelationKind] {
        RelationKind.allCases.filter { $0 != .subtask && $0 != .parenttask }
    }

    var body: some View {
        NavigationStack {
            List(kinds, id: \.self) { kind in
                Button {
                    onPick(kind)
                } label: {
                    HStack(spacing: VikunjaSpacing.sm) {
                        Image(systemName: "link")
                            .font(.system(size: 15))
                            .foregroundStyle(VikunjaColor.brandPrimary)
                        Text(kind.displayName)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VikunjaColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Relation Type")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// Searches every task on the instance (via
/// `TaskDetailViewModel.searchTasksForRelation(query:)`) to pick the other
/// side of a new relation of the given `kind`.
private struct RelationTaskPickerSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    let kind: RelationKind
    let onSelect: (VikunjaTask) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.relationSearchResults.isEmpty {
                    VStack {
                        Spacer()
                        Text(isSearching ? "No results" : "No other tasks in this project")
                            .font(VikunjaFont.subheadline)
                            .foregroundStyle(VikunjaColor.textTertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.relationSearchResults) { candidate in
                        Button {
                            onSelect(candidate)
                        } label: {
                            RelationCandidateRow(task: candidate, projectTitle: viewModel.projectTitle(forProjectID: candidate.projectID))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search tasks...")
            .onChange(of: query) { _, newValue in
                Task { await viewModel.searchTasksForRelation(query: newValue) }
            }
            .navigationTitle(kind.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.loadAllProjects()
            await viewModel.loadRelationSuggestions()
        }
    }
}

private struct RelationCandidateRow: View {
    let task: VikunjaTask
    let projectTitle: String?

    private var priorityColor: Color? {
        switch task.priority {
        case .unset: return nil
        case .low: return VikunjaColor.Priority.low
        case .medium: return VikunjaColor.Priority.medium
        case .high: return VikunjaColor.Priority.high
        case .urgent, .doNow: return VikunjaColor.Priority.urgent
        }
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm) {
            if let priorityColor {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                Text(task.title)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                if let projectTitle {
                    Text(projectTitle)
                        .font(VikunjaFont.caption)
                        .foregroundStyle(VikunjaColor.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VikunjaColor.brandPrimary)
        }
    }
}

private struct TaskDetailStatusView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: VikunjaSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(VikunjaColor.textTertiary)
            Text("Couldn't load this task")
                .font(VikunjaFont.headline)
            Text(message)
                .font(VikunjaFont.subheadline)
                .foregroundStyle(VikunjaColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retryAction)
                .buttonStyle(.bordered)
                .padding(.top, VikunjaSpacing.xs)
        }
        .padding(VikunjaSpacing.lg)
        .frame(maxWidth: .infinity)
    }
}

/// Lets the user pick (or clear) a due date/time. A small sheet rather than
/// an inline `DatePicker`, matching `QuickAddSheetView`'s pattern of pushing
/// pickers into their own sheet — `TaskDetailView` has no toolbar of its own
/// to host a "Done" button otherwise.
private struct DueDatePickerSheet: View {
    @State private var date: Date
    @Environment(\.dismiss) private var dismiss
    private let hadInitialDate: Bool
    private let onSave: (Date?) -> Void

    init(initialDate: Date?, onSave: @escaping (Date?) -> Void) {
        _date = State(initialValue: initialDate ?? Date())
        self.hadInitialDate = initialDate != nil
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    DatePicker("Due date", selection: $date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()

                    if hadInitialDate {
                        Button("Remove Due Date", role: .destructive) {
                            onSave(nil)
                            dismiss()
                        }
                        .padding(.top, VikunjaSpacing.sm)
                    }
                }
                .padding(.horizontal, VikunjaSpacing.md)
                .padding(.top, VikunjaSpacing.sm)
            }
            .navigationTitle("Due Date")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        // Two detents (not one fixed height) so the sheet can be dragged
        // taller — the graphical calendar plus the hour/minute wheel the
        // `.graphical` style appends below it don't both fit at the smaller
        // detent, and a fixed single detent left the wheel unreachable.
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
    }
}

/// Add/remove labels on the task, and create a new one on the fly — matches
/// the design mockup's label sheet. A `.searchable` list rather than a
/// custom text field, the same pattern `QuickAddSheetView`'s
/// `ProjectPickerView` uses; unlike that picker, tapping a row here toggles
/// membership instead of dismissing, since a task can carry more than one
/// label.
/// The "Move to Project" sheet: every other project on the instance, grouped
/// under its top-level project (mirrors `QuickAddSheetView`'s "Choose
/// Project" picker), filterable by `.searchable`. Unlike that picker, tapping
/// a row acts immediately — there's no separate "Save" step for a move — via
/// `onSelect`, which the caller uses to persist the change and pop the
/// screen.
private struct MoveProjectPickerSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    let onSelect: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredGroups: [TaskDetailViewModel.ProjectGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.moveProjectGroups }
        return viewModel.moveProjectGroups.compactMap { group in
            let rootMatches = group.root.title.localizedCaseInsensitiveContains(trimmed)
            let matchingChildren = group.children.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
            guard rootMatches || !matchingChildren.isEmpty else { return nil }
            return TaskDetailViewModel.ProjectGroup(root: group.root, children: rootMatches ? group.children : matchingChildren)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VikunjaSpacing.lg) {
                    ForEach(filteredGroups) { group in
                        VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                            MoveProjectPickerRow(project: group.root, isBold: true) { select(group.root) }
                            ForEach(group.children) { child in
                                MoveProjectPickerRow(project: child, isBold: false) { select(child) }
                                    .padding(.leading, VikunjaSpacing.lg)
                            }
                        }
                    }
                }
                .padding(.vertical, VikunjaSpacing.sm)
            }
            .searchable(text: $query, prompt: "Search projects...")
            .navigationTitle("Move to Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.loadAllProjects() }
    }

    private func select(_ project: Project) {
        dismiss()
        onSelect(project)
    }
}

private struct MoveProjectPickerRow: View {
    let project: Project
    let isBold: Bool
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
            }
            .padding(.horizontal, VikunjaSpacing.md)
            .padding(.vertical, VikunjaSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LabelPickerSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var pickedColor = VikunjaColor.SwatchPalette.swatches[0]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredLabels: [VikunjaCore.Label] {
        guard !trimmedQuery.isEmpty else { return viewModel.allLabels }
        return viewModel.allLabels.filter { $0.title.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    private var hasExactMatch: Bool {
        viewModel.allLabels.contains { $0.title.caseInsensitiveCompare(trimmedQuery) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VikunjaSpacing.xs) {
                    ForEach(filteredLabels) { label in
                        LabelPickerRow(label: label, isSelected: viewModel.task.labels.contains(label)) {
                            Task { await viewModel.toggleLabel(label) }
                        }
                    }

                    if !trimmedQuery.isEmpty, !hasExactMatch {
                        CreateLabelCard(title: trimmedQuery, pickedColor: $pickedColor) {
                            let title = trimmedQuery
                            let color = pickedColor
                            query = ""
                            Task { await viewModel.createAndAddLabel(title: title, hexColor: color) }
                        }
                    }
                }
                .padding(.vertical, VikunjaSpacing.sm)
            }
            .searchable(text: $query, prompt: "Search or create label...")
            .navigationTitle("Labels")
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
        .task { await viewModel.loadAllLabels() }
    }
}

private struct LabelPickerRow: View {
    let label: VikunjaCore.Label
    let isSelected: Bool
    let action: () -> Void

    private var color: Color {
        Color(vikunjaHex: label.hexColor) ?? VikunjaColor.textSecondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VikunjaSpacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label.title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.primary)
                Spacer()
                // An explicit checkbox rather than a checkmark that only
                // appears once selected — an empty circle makes it obvious
                // up front that rows are multi-select, not "pick one".
                LabelSelectionIndicator(isSelected: isSelected)
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

/// A quieter checkbox than `TaskDetailCheckbox` — a thin, low-opacity ring
/// that fills with a soft gray tint (not a solid color) and a muted
/// checkmark, matching the mockup's subtler treatment for "is this label
/// picked" versus the task's own bold completion toggle.
private struct LabelSelectionIndicator: View {
    let isSelected: Bool
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .strokeBorder(VikunjaColor.textTertiary.opacity(isSelected ? 0 : 0.4), lineWidth: 1.5)
            .background(Circle().fill(VikunjaColor.textTertiary.opacity(isSelected ? 0.22 : 0)))
            .frame(width: size, height: size)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(VikunjaColor.textSecondary)
                }
            }
    }
}

/// Offered only once the search query doesn't match any existing label
/// exactly — lets the user pick a swatch from `VikunjaColor.SwatchPalette`
/// and create+attach the label in one tap.
private struct CreateLabelCard: View {
    let title: String
    @Binding var pickedColor: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.sm) {
            Text("Create New Label")
                .font(VikunjaFont.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(VikunjaColor.textSecondary)

            HStack(spacing: VikunjaSpacing.sm) {
                Circle()
                    .fill(Color(vikunjaHex: pickedColor) ?? VikunjaColor.brandPrimary)
                    .frame(width: 12, height: 12)
                Text("\"\(title)\"")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(VikunjaColor.SwatchPalette.swatches, id: \.self) { swatch in
                    Circle()
                        .fill(Color(vikunjaHex: swatch) ?? VikunjaColor.brandPrimary)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if swatch == pickedColor {
                                Circle().strokeBorder(Color.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { pickedColor = swatch }
                }
            }

            Button(action: action) {
                Text("Create and Add")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VikunjaSpacing.sm)
                    .background(VikunjaColor.brandPrimary, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(VikunjaSpacing.md - VikunjaSpacing.xxs)
        .background(VikunjaColor.Surface.field, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
        .padding(.horizontal, VikunjaSpacing.sm)
        .padding(.top, VikunjaSpacing.xs)
    }
}

/// The task's comment thread: existing comments (oldest first, matching
/// Vikunja's own order) plus the composer to post a new one. A failure
/// loading comments only replaces the "no comments yet" placeholder — the
/// composer stays available either way, matching the design mockup, which
/// never blocks posting on the thread having loaded successfully.
private struct CommentsSection: View {
    let comments: [TaskComment]
    let loadState: ScreenLoadState
    let onSubmit: (String) -> Void
    @State private var draft = ""

    private var emptyStateMessage: String {
        if case .failure(let message) = loadState { return message }
        return "No comments yet."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VikunjaSpacing.md - VikunjaSpacing.xxs) {
            if comments.isEmpty {
                Text(emptyStateMessage)
                    .font(VikunjaFont.subheadline)
                    .foregroundStyle(VikunjaColor.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: VikunjaSpacing.md - VikunjaSpacing.xxs) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
            }

            CommentComposer(draft: $draft) {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                draft = ""
                onSubmit(text)
            }
        }
    }
}

private struct CommentRow: View {
    let comment: TaskComment

    private var displayName: String {
        let name = comment.author.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false) ? name! : comment.author.username
    }

    private var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: VikunjaSpacing.sm) {
            Circle()
                .fill(VikunjaColor.Surface.field)
                .frame(width: 30, height: 30)
                .overlay {
                    Text(initials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VikunjaColor.textSecondary)
                }

            VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: VikunjaSpacing.xs) {
                    Text(displayName)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text(CommentTimeFormatter.string(for: comment.created))
                        .font(.system(size: 12))
                        .foregroundStyle(VikunjaColor.textTertiary)
                }
                Text(CommentTextFormatter.plainText(from: comment.comment))
                    .font(.system(size: 14.5))
                    .foregroundStyle(VikunjaColor.textSecondary)
            }
            .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.xs + VikunjaSpacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VikunjaColor.Surface.card, in: RoundedRectangle(cornerRadius: VikunjaRadius.md, style: .continuous))
        }
    }
}

private struct CommentComposer: View {
    @Binding var draft: String
    let onSubmit: () -> Void

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.xs) {
            TextField("Write a comment...", text: $draft)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
                .submitLabel(.send)
                .onSubmit(onSubmit)
                .padding(.leading, VikunjaSpacing.sm)
                .padding(.vertical, VikunjaSpacing.xs + VikunjaSpacing.xxs)

            Button(action: onSubmit) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(canSubmit ? .white : VikunjaColor.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(canSubmit ? VikunjaColor.brandPrimary : VikunjaColor.Surface.field, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(.trailing, VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.xxs)
        .background(VikunjaColor.Surface.card, in: Capsule())
    }
}

/// Vikunja stores a comment's body as the rich-text editor's HTML output;
/// this feature has no rich-text renderer yet, so comments render as plain
/// text — stripped of markup rather than shown as raw `<p>...</p>`.
private enum CommentTextFormatter {
    static func plainText(from html: String) -> String {
        let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return stripped
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
private enum CommentTimeFormatter {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func string(for date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Formats a due date the way the design mirrors relative-day phrasing
/// (today/tomorrow/yesterday/weekday) before falling back to an absolute date.
private enum TaskDueDateFormatter {
    static func string(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today, \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
        if abs(days) <= 6 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
