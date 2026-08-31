import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

struct SearchView: View {
    @State var viewModel: SearchViewModel
    var onTaskSelected: ((VikunjaTask, Project) -> AnyView)?
    @State private var taskPendingDelete: VikunjaTask?
    @State private var selectedTaskPair: SearchTaskPair?

    var body: some View {
        searchContent
            .animation(.easeInOut(duration: 0.2), value: viewModel.state.value?.map(\.id))
            .searchListStyle()
            .scrollContentBackground(.hidden)
            .background(VikunjaColor.Surface.page)
            .navigationTitle("Search")
            .navigationDestination(item: $selectedTaskPair) { item in
                if let onTaskSelected {
                    onTaskSelected(item.task, item.project)
                }
            }
            .confirmationDialog(
                "This permanently deletes the task.",
                isPresented: Binding(
                    get: { taskPendingDelete != nil },
                    set: {
                        isPresented in if !isPresented {
                            taskPendingDelete = nil
                        }
                    },
                ),
                titleVisibility: .visible,
            ) {
                if let taskPendingDelete {
                    Button("Delete Task", role: .destructive) {
                        Task { await viewModel.delete(taskPendingDelete) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    private var searchContent: some View {
        List {
            switch viewModel.state {
            case .idle:
                emptyState
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, VikunjaSpacing.xxl)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

            case let .loaded(tasks):
                if tasks.isEmpty {
                    emptySearchResultsState
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    loadedContent(tasks)
                }

            case let .failure(message):
                VStack(spacing: VikunjaSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text("Search Error")
                        .font(VikunjaFont.headline)
                    Text(message)
                        .font(VikunjaFont.subheadline)
                        .foregroundStyle(VikunjaColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(VikunjaSpacing.lg)
                .frame(maxWidth: .infinity)
                .padding(.top, VikunjaSpacing.lg)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func loadedContent(_ tasks: [VikunjaTask]) -> some View {
        HStack(spacing: VikunjaSpacing.xs) {
            Text("RESULTS")
                .fontWeight(.bold)
            Text("\(tasks.count)")
                .fontWeight(.regular)
        }
        .searchSectionLabelStyle()
        .padding(.horizontal, VikunjaSpacing.md)
        .padding(.top, VikunjaSpacing.md + VikunjaSpacing.xs)
        .padding(.bottom, VikunjaSpacing.sm)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
            if let project = viewModel.projectsByID[task.projectID] {
                SearchTaskRow(
                    task: task,
                    project: project,
                    onToggle: {
                        Task { await viewModel.toggleDone(task) }
                    },
                    onOpen: {
                        selectedTaskPair = SearchTaskPair(task: task, project: project)
                    },
                    onDelete: {
                        taskPendingDelete = task
                    },
                )
                .padding(.horizontal, VikunjaSpacing.md)
                .padding(.vertical, VikunjaSpacing.md)
                .background(VikunjaColor.Surface.card)
                .overlay(alignment: .bottom) {
                    if index < tasks.count - 1 {
                        Divider().padding(.leading, VikunjaSpacing.md)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: index == 0 ? VikunjaRadius.lg : 0,
                        bottomLeadingRadius: index == tasks.count - 1 ? VikunjaRadius.lg : 0,
                        bottomTrailingRadius: index == tasks.count - 1 ? VikunjaRadius.lg : 0,
                        topTrailingRadius: index == 0 ? VikunjaRadius.lg : 0,
                        style: .continuous,
                    ),
                )
                .padding(.horizontal, VikunjaSpacing.sm + VikunjaSpacing.xs)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: VikunjaSpacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Search Tasks")
                .font(VikunjaFont.headline)
            Text("Type a query to search all your tasks")
                .font(VikunjaFont.subheadline)
                .foregroundStyle(VikunjaColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VikunjaSpacing.lg)
    }

    private var emptySearchResultsState: some View {
        VStack(spacing: VikunjaSpacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(VikunjaFont.headline)
            Text("No tasks match your search")
                .font(VikunjaFont.subheadline)
                .foregroundStyle(VikunjaColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VikunjaSpacing.lg)
    }
}

private struct SearchTaskRow: View {
    static let labelDisplayLimit = 2

    let task: VikunjaTask
    let project: Project
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void

    private var projectColor: Color {
        Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary
    }

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isDone else { return false }
        return dueDate < Date()
    }

    private var priorityColor: Color? {
        switch task.priority {
        case .unset: nil
        case .low: VikunjaColor.Priority.low
        case .medium: VikunjaColor.Priority.medium
        case .high: VikunjaColor.Priority.high
        case .urgent, .doNow: VikunjaColor.Priority.urgent
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
                    HStack(spacing: VikunjaSpacing.xs) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(projectColor)
                            .frame(width: 6, height: 6)
                        Text(project.title)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(VikunjaColor.textSecondary)
                    }

                    if task.dueDate != nil {
                        Text("·")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VikunjaColor.textSecondary)
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
                            SearchLabelPill(label: label)
                        }

                        let remainingLabelCount = task.labels.count - Self.labelDisplayLimit
                        if remainingLabelCount > 0 {
                            SearchExtraLabelsPill(count: remainingLabelCount)
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
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                .tint(VikunjaColor.Semantic.danger)
        }
    }
}

private struct SearchLabelPill: View {
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

private struct SearchExtraLabelsPill: View {
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

#Preview {
    NavigationStack {
        SearchView(viewModel: SearchViewModel(
            taskRepository: PreviewTaskRepository(),
            projectRepository: PreviewProjectRepository(),
            toastPresenter: PreviewToastPresenter(),
        ))
    }
}

private struct SearchTaskPair: Identifiable, Hashable {
    let task: VikunjaTask
    let project: Project
    var id: Int {
        task.id
    }
}

private extension View {
    func searchListStyle() -> some View {
        listStyle(.plain)
    }
}

private extension View {
    func searchSectionLabelStyle() -> some View {
        font(VikunjaFont.footnote)
            .fontWeight(.bold)
            .foregroundStyle(VikunjaColor.textSecondary)
            .textCase(.uppercase)
            .kerning(0.3)
    }
}

// MARK: - Preview Helpers

private final class PreviewTaskRepository: @unchecked Sendable, TaskRepositoryProtocol {
    func fetchTasks(projectID _: Int) async throws -> [VikunjaTask] {
        []
    }

    func fetchTask(id _: Int) async throws -> VikunjaTask {
        VikunjaTask(id: 0, title: "", projectID: 0)
    }

    func create(_ task: VikunjaTask) async throws -> VikunjaTask {
        task
    }

    func update(_ task: VikunjaTask) async throws -> VikunjaTask {
        task
    }

    func delete(id _: Int) async throws {}
    func searchTasks(query _: String) async throws -> [VikunjaTask] {
        []
    }
}

private final class PreviewProjectRepository: @unchecked Sendable, ProjectRepositoryProtocol {
    func fetchProjects() async throws -> [Project] {
        []
    }

    func fetchProject(id _: Int) async throws -> Project {
        Project(id: 0, title: "")
    }

    func create(_ project: Project) async throws -> Project {
        project
    }

    func update(_ project: Project) async throws -> Project {
        project
    }

    func delete(id _: Int) async throws {}
}

private final class PreviewToastPresenter: @unchecked Sendable, ToastPresenting {
    func show(_: String, style _: VikunjaCore.ToastStyle) {}
}
