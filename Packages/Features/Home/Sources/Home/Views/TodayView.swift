import SwiftUI
import VikunjaCore
import VikunjaDesignSystem
import VikunjaNavigation

/// The Today screen: every project's tasks, grouped by due date into
/// Overdue/Today/Upcoming. Tasks without a due date never appear here — only
/// inside their own project.
struct TodayView: View {
    @Bindable var viewModel: TodayViewModel
    let router: Router<HomeRoute>
    @State private var filter: TodayFilter = .all

    var body: some View {
        content
            .todayListStyle()
            .scrollContentBackground(.hidden)
            .background(VikunjaColor.Surface.page)
            .refreshable { await viewModel.load() }
            .navigationTitle("Today")
            .task { await viewModel.load() }
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
                TodayStatusView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load your tasks",
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
        // `.plain` list style (see `todayListStyle()`) so every row here is
        // flush with `.navigationTitle` by default — see `ProjectOverviewView`
        // for the same reasoning.
        VStack(alignment: .leading, spacing: VikunjaSpacing.md) {
            Text(pendingSubtitle)
                .font(VikunjaFont.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(VikunjaColor.textSecondary)
                .padding(.horizontal, VikunjaSpacing.md)

            TodayFilterRow(selection: $filter)
                .padding(.horizontal, VikunjaSpacing.md)
        }
        .padding(.vertical, VikunjaSpacing.xs)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        let visible = TodaySection.sections(from: viewModel.tasks, filter: filter)
        if visible.isEmpty {
            TodayStatusView(
                systemImage: "checkmark.circle",
                title: datedTaskCount == 0 ? "Nothing due" : "Nothing here",
                message: datedTaskCount == 0
                    ? "Tasks with a due date will show up here."
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

                // Each task is its own `List` row so a long-press/tap only
                // ever targets the one row under the finger — see
                // `ProjectOverviewView`'s equivalent comment for the full
                // reasoning behind this per-row card recipe.
                ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                    TodayTaskRow(task: task, project: viewModel.projectsByID[task.projectID]) {
                        Task { await viewModel.toggleDone(task) }
                    } onOpen: {
                        if let project = viewModel.projectsByID[task.projectID] {
                            router.push(.taskDetail(task, project))
                        }
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
                    .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xs)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private var datedTaskCount: Int {
        viewModel.tasks.filter { $0.dueDate != nil }.count
    }

    private var pendingSubtitle: String {
        let pending = viewModel.tasks.filter { $0.dueDate != nil && !$0.isDone }.count
        return pending == 1 ? "1 task pending" : "\(pending) tasks pending"
    }
}

/// Status filter for the Today screen's due-date buckets.
enum TodayFilter: CaseIterable {
    case all, overdue, today, upcoming

    var title: String {
        switch self {
        case .all: return "All"
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        }
    }
}

private struct TodayFilterRow: View {
    @Binding var selection: TodayFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VikunjaSpacing.sm) {
                ForEach(TodayFilter.allCases, id: \.self) { option in
                    TodayFilterChip(title: option.title, isSelected: selection == option) {
                        selection = option
                    }
                }
            }
        }
        // Without this, the first chip sits further right than the row it's
        // in — same nested-ScrollView quirk `ProjectOverviewView` works around.
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }
}

private struct TodayFilterChip: View {
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

/// One due-date bucket within the filtered list — Overdue/Today/Upcoming,
/// only showing the ones the current filter and data actually produce.
struct TodaySection: Identifiable {
    let title: String
    let tasks: [VikunjaTask]
    var id: String { title }

    static func sections(from tasks: [VikunjaTask], filter: TodayFilter) -> [TodaySection] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return []
        }

        // Tasks with no due date never appear on this screen — only inside
        // their own project.
        let dated = tasks.filter { $0.dueDate != nil }

        func isOverdue(_ task: VikunjaTask) -> Bool {
            guard let dueDate = task.dueDate, !task.isDone else { return false }
            return dueDate < startOfToday
        }
        func isToday(_ task: VikunjaTask) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfToday && dueDate < startOfTomorrow
        }
        func isUpcoming(_ task: VikunjaTask) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfTomorrow
        }

        let filtered: [VikunjaTask]
        switch filter {
        case .all: filtered = dated
        case .overdue: filtered = dated.filter(isOverdue)
        case .today: filtered = dated.filter(isToday)
        case .upcoming: filtered = dated.filter(isUpcoming)
        }

        return [
            ("Overdue", filtered.filter(isOverdue)),
            ("Today", filtered.filter(isToday)),
            ("Upcoming", filtered.filter(isUpcoming)),
        ].compactMap { title, tasks in tasks.isEmpty ? nil : TodaySection(title: title, tasks: tasks) }
    }
}

private struct TodayTaskRow: View {
    static let labelDisplayLimit = 2

    let task: VikunjaTask
    let project: Project?
    let onToggle: () -> Void
    let onOpen: () -> Void

    private var projectColor: Color {
        project.flatMap { Color(vikunjaHex: $0.hexColor) } ?? VikunjaColor.brandPrimary
    }

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
                    if let project {
                        HStack(spacing: VikunjaSpacing.xs) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(projectColor)
                                .frame(width: 6, height: 6)
                            Text(project.title)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundStyle(VikunjaColor.textSecondary)
                        }
                    }

                    if project != nil, task.dueDate != nil {
                        Text("·")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(VikunjaColor.textTertiary)
                    }

                    if isOverdue {
                        Text("Overdue")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(VikunjaColor.Semantic.dangerText)
                    } else if let dueDate = task.dueDate {
                        Text(dueDate, style: .date)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(VikunjaColor.textSecondary)
                    }

                    if task.hasRelations {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(VikunjaColor.textTertiary)
                    }
                }

                if !task.labels.isEmpty {
                    HStack(spacing: VikunjaSpacing.xs + VikunjaSpacing.xxs) {
                        ForEach(task.labels.prefix(Self.labelDisplayLimit)) { label in
                            TodayLabelPill(label: label)
                        }

                        let remainingLabelCount = task.labels.count - Self.labelDisplayLimit
                        if remainingLabelCount > 0 {
                            TodayExtraLabelsPill(count: remainingLabelCount)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}

private struct TodayLabelPill: View {
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

private struct TodayExtraLabelsPill: View {
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
    /// `.plain`, not `.insetGrouped` — see `ProjectOverviewView.projectsListStyle()`
    /// for why: `.insetGrouped` always floats its content in from the screen
    /// edges by a fixed system margin that can't be tuned away.
    func todayListStyle() -> some View {
        listStyle(.plain)
    }
}

private extension View {
    func overviewSectionLabelStyle() -> some View {
        font(VikunjaFont.footnote)
            .fontWeight(.bold)
            .foregroundStyle(VikunjaColor.textSecondary)
            .textCase(.uppercase)
            .kerning(0.3)
    }
}

private struct TodayStatusView: View {
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
