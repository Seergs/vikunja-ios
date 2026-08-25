import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// A single task's detail screen: completion, due date, priority, labels,
/// subtasks, and dependencies. Pushed as a leaf screen inside whichever
/// feature's `NavigationStack` opened it (Projects, today) — this package
/// owns no `NavigationStack`/`Router` of its own.
public struct TaskDetailView: View {
    @Bindable var viewModel: TaskDetailViewModel
    @State private var isShowingDueDatePicker = false
    @State private var isShowingLabelPicker = false

    public init(viewModel: TaskDetailViewModel) {
        self.viewModel = viewModel
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
        .navigationTitle("Task Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.load() }
        .sheet(isPresented: $isShowingDueDatePicker) {
            DueDatePickerSheet(initialDate: viewModel.task.dueDate) { newDate in
                Task { await viewModel.setDueDate(newDate) }
            }
        }
        .sheet(isPresented: $isShowingLabelPicker) {
            LabelPickerSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        let task = viewModel.task
        let project = viewModel.project

        ProjectPill(project: project)
            .padding(.top, VikunjaSpacing.sm)

        HStack(alignment: .top, spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
            Button {
                Task { await viewModel.toggleDone() }
            } label: {
                TaskDetailCheckbox(isDone: task.isDone, color: swatchColor(project))
            }
            .buttonStyle(.plain)
            .padding(.top, VikunjaSpacing.xxs)

            Text(task.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primary)
                .strikethrough(task.isDone)
        }
        .padding(.top, VikunjaSpacing.sm)

        if task.isBlocked {
            BlockedBanner(waitingOn: task.dependsOn.filter { !$0.isDone }.count)
                .padding(.top, VikunjaSpacing.md)
        }

        if let description = task.description, !description.isEmpty {
            Text(description)
                .font(VikunjaFont.callout)
                .foregroundStyle(VikunjaColor.textSecondary)
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

        if !task.dependsOn.isEmpty {
            SectionBlock(title: "Depends on") {
                VStack(spacing: VikunjaSpacing.sm) {
                    ForEach(task.dependsOn) { relation in
                        DependencyRow(relation: relation, projectTitle: projectTitle(for: relation))
                    }
                }
            }
        }

        if !task.blocks.isEmpty {
            SectionBlock(title: "Blocks") {
                VStack(spacing: VikunjaSpacing.sm) {
                    ForEach(task.blocks) { relation in
                        DependencyRow(relation: relation, projectTitle: projectTitle(for: relation))
                    }
                }
            }
        }

        ForEach(orderedOtherRelations(task), id: \.kind) { entry in
            SectionBlock(title: entry.kind.displayName) {
                VStack(spacing: VikunjaSpacing.sm) {
                    ForEach(entry.relations) { relation in
                        DependencyRow(relation: relation, projectTitle: projectTitle(for: relation))
                    }
                }
            }
        }
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

private struct DependencyRow: View {
    let relation: TaskRelation
    let projectTitle: String?

    var body: some View {
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
        .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xxs)
        .padding(.vertical, VikunjaSpacing.sm)
        .background(VikunjaColor.Surface.card, in: RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous))
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

                Spacer(minLength: 0)
            }
            .padding(.horizontal, VikunjaSpacing.md)
            .padding(.top, VikunjaSpacing.sm)
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
        .presentationDetents([.fraction(0.6)])
        .presentationDragIndicator(.visible)
    }
}

/// Add/remove labels on the task, and create a new one on the fly — matches
/// the design mockup's label sheet. A `.searchable` list rather than a
/// custom text field, the same pattern `QuickAddSheetView`'s
/// `ProjectPickerView` uses; unlike that picker, tapping a row here toggles
/// membership instead of dismissing, since a task can carry more than one
/// label.
private struct LabelPickerSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var pickedColor = VikunjaColor.LabelPalette.swatches[0]

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
/// exactly — lets the user pick a swatch from `VikunjaColor.LabelPalette`
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
                ForEach(VikunjaColor.LabelPalette.swatches, id: \.self) { swatch in
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
