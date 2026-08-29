import SwiftUI
import VikunjaCore
import VikunjaDesignSystem
import VikunjaNavigation

/// A single project's overview: its subprojects (if any), a status filter,
/// and its own tasks grouped by overdue/pending/completed.
struct ProjectOverviewView: View {
    @Bindable var viewModel: ProjectOverviewViewModel
    let router: Router<ProjectsRoute>
    @State private var filter: ProjectTaskFilter = .all
    @State private var taskPendingDelete: VikunjaTask?
    @State private var taskPendingMove: VikunjaTask?

    var body: some View {
        content
            .projectsListStyle()
            .scrollContentBackground(.hidden)
            .background(VikunjaColor.Surface.page)
            .refreshable { await viewModel.load() }
            .navigationTitle(viewModel.project.title)
            .task { await viewModel.load() }
            .confirmationDialog(
                "This permanently deletes the task.",
                isPresented: Binding(
                    get: { taskPendingDelete != nil },
                    set: { isPresented in if !isPresented { taskPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let taskPendingDelete {
                    Button("Delete Task", role: .destructive) {
                        Task { await viewModel.delete(taskPendingDelete) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $taskPendingMove) { task in
                MoveTaskProjectPickerSheet(viewModel: viewModel) { destination in
                    Task { await viewModel.move(task, to: destination) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        List {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, VikunjaSpacing.xxl)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            case let .failure(message):
                ProjectOverviewStatusView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load this project",
                    message: message
                ) {
                    Task { await viewModel.load() }
                }
                .padding(.top, VikunjaSpacing.xxl)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            case .loaded:
                loadedContent
            }
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        // `.plain` list style (see `projectsListStyle()`) so every row here
        // is flush with `.navigationTitle` by default, with `EdgeInsets()`
        // to strip even the small residual default `.plain` gives rows —
        // our own `.padding(.horizontal, VikunjaSpacing.md)` inside each
        // piece below is the only horizontal offset left, so it can't stack
        // with a system default the way it did under `.insetGrouped`.
        VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
            ProjectProgressHeader(project: viewModel.project, tasks: viewModel.tasks)
                .padding(.horizontal, VikunjaSpacing.md)

            if !viewModel.subprojects.isEmpty {
                VStack(alignment: .leading, spacing: VikunjaSpacing.sm) {
                    HStack(spacing: VikunjaSpacing.xs) {
                        Text("Subprojects")
                            .fontWeight(.bold)
                        Text("\(viewModel.subprojects.count)")
                            .fontWeight(.regular)
                    }
                    .overviewSectionLabelStyle()
                    .padding(.horizontal, VikunjaSpacing.md)

                    SubprojectScrollRow(
                        subprojects: viewModel.subprojects,
                        taskSummaries: viewModel.subprojectTaskSummaries
                    ) { subproject in
                        router.push(.projectOverview(subproject))
                    }
                    .padding(.horizontal, VikunjaSpacing.md)
                }
                // A bit more than the parent `VStack`'s own spacing, just
                // for the gap after "X/Y tasks completed" specifically.
                .padding(.top, VikunjaSpacing.xs)
            }

            ProjectTaskFilterRow(selection: $filter)
                .padding(.horizontal, VikunjaSpacing.md)
        }
        .padding(.vertical, VikunjaSpacing.xs)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        let visible = ProjectTaskSection.sections(from: viewModel.tasks, filter: filter)
        if visible.isEmpty {
            ProjectOverviewStatusView(
                systemImage: "checkmark.circle",
                title: viewModel.tasks.isEmpty ? "No tasks yet" : "Nothing here",
                message: viewModel.tasks.isEmpty
                    ? "Tasks in this project will show up here."
                    : "No tasks match this filter.",
                iconSize: 28
            )
            .padding(.top, VikunjaSpacing.lg)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            ForEach(visible) { section in
                HStack(spacing: VikunjaSpacing.xs) {
                    Text(section.title)
                        .fontWeight(.bold)
                    Text("\(section.tasks.count)")
                        .fontWeight(.regular)
                }
                .overviewSectionLabelStyle()
                .padding(.horizontal, VikunjaSpacing.md)
                .padding(.top, VikunjaSpacing.md + VikunjaSpacing.xs)
                .padding(.bottom, VikunjaSpacing.sm)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Each task is its own `List` row (rather than all of them
                // sharing one row inside a `VStack`, as a single card) so a
                // long-press's highlight and `.contextMenu` only ever target
                // the one row under the finger — packed into a shared row,
                // `List` highlights the whole row, i.e. every task in the
                // section at once. The rounded "card" look is recreated by
                // hand across these now-separate rows: only the first row
                // rounds its top corners, only the last rounds its bottom
                // corners, and a manual divider (not `List`'s own, hidden via
                // `.listRowSeparator`) sits between adjacent ones.
                ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                    ProjectTaskRow(task: task, projectColor: swatchColor) {
                        Task { await viewModel.toggleDone(task) }
                    } onOpen: {
                        router.push(.taskDetail(task, viewModel.project))
                    } onMove: {
                        taskPendingMove = task
                    } onDelete: {
                        taskPendingDelete = task
                    }
                    .padding(.horizontal, VikunjaSpacing.md)
                    .padding(.vertical, VikunjaSpacing.sm)
                    .background(VikunjaColor.Surface.card)
                    .overlay(alignment: .bottom) {
                        if index < section.tasks.count - 1 {
                            Divider().padding(.leading, VikunjaSpacing.md)
                        }
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: index == 0 ? VikunjaRadius.lg : 0,
                            bottomLeadingRadius: index == section.tasks.count - 1 ? VikunjaRadius.lg : 0,
                            bottomTrailingRadius: index == section.tasks.count - 1 ? VikunjaRadius.lg : 0,
                            topTrailingRadius: index == 0 ? VikunjaRadius.lg : 0,
                            style: .continuous
                        )
                    )
                    // Only the card itself gets breathing room from the
                    // screen edges — the label above it stays flush with
                    // the title, matching everything else on this screen.
                    .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xs)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private var swatchColor: Color {
        Color(vikunjaHex: viewModel.project.hexColor) ?? VikunjaColor.brandPrimary
    }
}

/// The project's title (via `.navigationTitle`) is handled by the nav bar;
/// this adds the color swatch + completion count beneath it, matching the
/// design's "■ X/Y tasks completed" subtitle.
private struct ProjectProgressHeader: View {
    let project: Project
    let tasks: [VikunjaTask]

    private var swatchColor: Color {
        Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm - VikunjaSpacing.xxs) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(swatchColor)
                .frame(width: 10, height: 10)

            Text(subtitle)
                .font(VikunjaFont.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(VikunjaColor.textSecondary)
        }
    }

    private var subtitle: String {
        guard !tasks.isEmpty else { return "No tasks yet" }
        let done = tasks.filter(\.isDone).count
        return "\(done)/\(tasks.count) tasks completed"
    }
}

/// Horizontally scrolling cards for this project's direct children, each
/// showing its own task-completion summary (recursively fetched alongside
/// the current project's own tasks — see `ProjectOverviewViewModel.load()`).
private struct SubprojectScrollRow: View {
    let subprojects: [ProjectNode]
    let taskSummaries: [Int: ProjectOverviewViewModel.TaskSummary]
    let onSelect: (ProjectNode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(subprojects) { node in
                    SubprojectCard(node: node, taskSummary: taskSummaries[node.id]) { onSelect(node) }
                }
            }
        }
        // Nested inside a `List` row, a horizontal `ScrollView` otherwise
        // inherits an automatic leading content margin from its ancestors —
        // zeroing it here is what makes the first card start exactly where
        // the row itself starts, instead of a bit further right.
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }
}

private struct SubprojectCard: View {
    let node: ProjectNode
    let taskSummary: ProjectOverviewViewModel.TaskSummary?
    let onSelect: () -> Void

    private var swatchColor: Color {
        Color(vikunjaHex: node.project.hexColor) ?? VikunjaColor.brandPrimary
    }

    private var summaryText: String {
        guard let taskSummary, taskSummary.total > 0 else { return "No tasks yet" }
        return "\(taskSummary.done)/\(taskSummary.total) tasks"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: VikunjaSpacing.sm) {
                RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous)
                    .fill(swatchColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(swatchColor)
                            .frame(width: 12, height: 12)
                    }

                VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                    Text(node.project.title)
                        .font(VikunjaFont.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(summaryText)
                        .font(VikunjaFont.caption)
                        .foregroundStyle(VikunjaColor.textTertiary)
                }

                Spacer(minLength: VikunjaSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VikunjaColor.textTertiary)
            }
            .padding(VikunjaSpacing.sm + VikunjaSpacing.xxs)
            // Fixed (not just minimum) width: the `Spacer` above needs a
            // bounded frame to expand into so the chevron reaches the card's
            // trailing edge — inside a horizontal `ScrollView`, a `Spacer`
            // under only a `minWidth` would try to grow unbounded instead.
            .frame(width: 220, alignment: .leading)
            .background(VikunjaColor.Surface.card, in: RoundedRectangle(cornerRadius: VikunjaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Status filter for this project's own task list.
enum ProjectTaskFilter: CaseIterable {
    case all, pending, overdue, completed

    var title: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .overdue: return "Overdue"
        case .completed: return "Completed"
        }
    }
}

private struct ProjectTaskFilterRow: View {
    @Binding var selection: ProjectTaskFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(ProjectTaskFilter.allCases, id: \.self) { option in
                    FilterChip(title: option.title, isSelected: selection == option) {
                        selection = option
                    }
                }
            }
        }
        // See `SubprojectScrollRow`: without this, the first chip sits
        // further right than the row it's in.
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(VikunjaFont.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
                .padding(.vertical, VikunjaSpacing.sm - VikunjaSpacing.xxs)
                .foregroundStyle(isSelected ? Color.white : VikunjaColor.textSecondary)
                .background(
                    Capsule().fill(isSelected ? VikunjaColor.brandPrimary : VikunjaColor.Surface.field)
                )
        }
        .buttonStyle(.plain)
    }
}

/// One status grouping of tasks within the filtered list — mirrors the
/// design's "Overdue" / "Pending" / "Completed" sections, only showing the
/// ones the current filter and data actually produce.
private struct ProjectTaskSection: Identifiable {
    let title: String
    let tasks: [VikunjaTask]
    var id: String { title }

    static func sections(from tasks: [VikunjaTask], filter: ProjectTaskFilter) -> [ProjectTaskSection] {
        let now = Date()
        func isOverdue(_ task: VikunjaTask) -> Bool {
            guard let dueDate = task.dueDate, !task.isDone else { return false }
            return dueDate < now
        }

        let filtered: [VikunjaTask]
        switch filter {
        case .all: filtered = tasks
        case .pending: filtered = tasks.filter { !$0.isDone }
        case .overdue: filtered = tasks.filter(isOverdue)
        case .completed: filtered = tasks.filter(\.isDone)
        }

        func sortedByDueDate(_ tasks: [VikunjaTask]) -> [VikunjaTask] {
            tasks.sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (lhsDate?, rhsDate?):
                    if lhsDate != rhsDate { return lhsDate < rhsDate }
                    return lhs.id < rhs.id
                case (nil, nil):
                    return lhs.id < rhs.id
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                }
            }
        }

        let overdue = filtered.filter(isOverdue)
        let pending = filtered.filter { !$0.isDone && !isOverdue($0) }
        let completed = filtered.filter(\.isDone)

        return [
            overdue.isEmpty ? nil : ProjectTaskSection(title: "Overdue", tasks: sortedByDueDate(overdue)),
            pending.isEmpty ? nil : ProjectTaskSection(title: "Pending", tasks: sortedByDueDate(pending)),
            completed.isEmpty ? nil : ProjectTaskSection(title: "Completed", tasks: sortedByDueDate(completed)),
        ].compactMap { $0 }
    }
}

private struct ProjectTaskRow: View {
    static let labelDisplayLimit = 2

    let task: VikunjaTask
    let projectColor: Color
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isDone else { return false }
        return dueDate < Date()
    }

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
        HStack(alignment: .top, spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
            Button(action: onToggle) {
                Circle()
                    .strokeBorder(task.isDone ? Color.clear : projectColor, lineWidth: 2)
                    .background(Circle().fill(task.isDone ? projectColor : Color.clear))
                    .frame(width: 24, height: 24)
                    .overlay {
                        if task.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: VikunjaSpacing.xs + VikunjaSpacing.xxs) {
                Text(task.title)
                    .font(VikunjaFont.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? VikunjaColor.textTertiary : Color.primary)

                HStack(spacing: VikunjaSpacing.xs + VikunjaSpacing.xxs) {
                    if let dueDate = task.dueDate {
                        Text(dueDate, style: .date)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(isOverdue ? VikunjaColor.Semantic.dangerText : VikunjaColor.textSecondary)
                    }

                    if task.hasRelations {
                        if task.dueDate == nil {
                            HStack(spacing: VikunjaSpacing.xxs) {
                                Image(systemName: "link")
                                    .font(.system(size: 11, weight: .regular))
                                Text("Related tasks")
                                    .font(.system(size: 12.5, weight: .regular))
                            }
                            .foregroundStyle(VikunjaColor.textTertiary)
                        } else {
                            Image(systemName: "link")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(VikunjaColor.textTertiary)
                        }
                    }
                }

                if !task.labels.isEmpty {
                    HStack(spacing: VikunjaSpacing.xs + VikunjaSpacing.xxs) {
                        ForEach(task.labels.prefix(Self.labelDisplayLimit)) { label in
                            LabelPill(label: label)
                        }

                        let remainingLabelCount = task.labels.count - Self.labelDisplayLimit
                        if remainingLabelCount > 0 {
                            ExtraLabelsPill(count: remainingLabelCount)
                        }
                    }
                }
            }

            Spacer(minLength: VikunjaSpacing.sm)

            if let priorityColor {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, VikunjaSpacing.xs)
            }
        }
        // The checkbox is its own `Button` above, so a tap landing on it is
        // handled there instead of bubbling up to this one — this only
        // catches taps on the rest of the row (title, due date, labels...).
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Move", systemImage: "folder", action: onMove)
            // `role: .destructive` alone renders blue here, not red: the tab
            // bar's `.tint(VikunjaColor.brandPrimary)` leaks into the context
            // menu and overrides the role's tint. Pin it back to danger.
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                .tint(VikunjaColor.Semantic.danger)
        }
    }
}

/// The "Move to Project" sheet, opened from a task row's long-press menu:
/// every other project on the instance, grouped under its top-level project
/// (mirrors `Features/Tasks`' own `MoveProjectPickerSheet` — a separate copy
/// since `Projects` can't import that package, see the "Rules for new code"
/// note in `CLAUDE.md`), filterable by `.searchable`. Tapping a row acts
/// immediately via `onSelect`, which the caller uses to persist the move.
private struct MoveTaskProjectPickerSheet: View {
    @Bindable var viewModel: ProjectOverviewViewModel
    let onSelect: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredGroups: [ProjectOverviewViewModel.ProjectGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.moveProjectGroups }
        return viewModel.moveProjectGroups.compactMap { group in
            let rootMatches = group.root.title.localizedCaseInsensitiveContains(trimmed)
            let matchingChildren = group.children.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
            guard rootMatches || !matchingChildren.isEmpty else { return nil }
            return ProjectOverviewViewModel.ProjectGroup(root: group.root, children: rootMatches ? group.children : matchingChildren)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VikunjaSpacing.lg) {
                    ForEach(filteredGroups) { group in
                        VStack(alignment: .leading, spacing: VikunjaSpacing.xxs) {
                            MoveTaskProjectPickerRow(project: group.root, isBold: true) { select(group.root) }
                            ForEach(group.children) { child in
                                MoveTaskProjectPickerRow(project: child, isBold: false) { select(child) }
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
        .task { await viewModel.loadMoveCandidates() }
    }

    private func select(_ project: Project) {
        dismiss()
        onSelect(project)
    }
}

private struct MoveTaskProjectPickerRow: View {
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

private struct ExtraLabelsPill: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(VikunjaColor.textTertiary)
            .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
            .padding(.vertical, VikunjaSpacing.xxs)
            .background(Capsule().fill(VikunjaColor.textSecondary.opacity(0.14)))
    }
}

private extension View {
    /// `.plain`, not `.insetGrouped`: `.insetGrouped` always floats its
    /// "card" content in from the screen edges by a fixed system margin,
    /// independent of any `listRowInsets` override — which is exactly what
    /// kept every row on this screen sitting to the right of
    /// `.navigationTitle` no matter how that override was tuned. `.plain`
    /// rows are flush by default, matching the title; `ProjectTaskRow`
    /// recreates the rounded "card" look by hand (per-row corner rounding)
    /// instead of relying on the list style to do it.
    func projectsListStyle() -> some View {
        listStyle(.plain)
    }
}

/// Shared look for the "Subprojects" label and the Overdue/Pending/Completed
/// task-status headers: small, bold, uppercase, and legible against
/// `VikunjaColor.textSecondary` rather than the system header's faint gray.
private extension View {
    func overviewSectionLabelStyle() -> some View {
        font(VikunjaFont.footnote)
            .fontWeight(.bold)
            .foregroundStyle(VikunjaColor.textSecondary)
            .textCase(.uppercase)
            .kerning(0.3)
    }
}

/// Shared empty/error state layout, matching `ProjectsView`'s.
private struct ProjectOverviewStatusView: View {
    let systemImage: String
    let title: String
    let message: String
    var iconSize: CGFloat = 40
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: VikunjaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
                .foregroundStyle(VikunjaColor.textTertiary)

            Text(title)
                .font(VikunjaFont.headline)

            Text(message)
                .font(VikunjaFont.subheadline)
                .foregroundStyle(VikunjaColor.textSecondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.bordered)
                    .padding(.top, VikunjaSpacing.xs)
            }
        }
        .padding(VikunjaSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
