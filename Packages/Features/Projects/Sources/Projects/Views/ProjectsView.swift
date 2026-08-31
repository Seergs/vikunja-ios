import SwiftUI
import VikunjaCore
import VikunjaDesignSystem
import VikunjaNavigation

/// The Projects tab's list screen: a flattened, indented rendering of
/// `ProjectsListViewModel.rootNodes` (a parent/child tree keyed by
/// `parentProjectID`), with per-project expand/collapse.
struct ProjectsView: View {
    @Bindable var viewModel: ProjectsListViewModel
    let router: Router<ProjectsRoute>
    let makeCreateProjectViewModel: () -> CreateProjectViewModel
    let makeEditProjectViewModel: (Project) -> EditProjectViewModel
    @State private var expandedProjectIDs: Set<Int> = []
    @State private var isShowingCreateProject = false
    @State private var projectPendingDelete: ProjectNode?
    @State private var editingProject: Project?

    var body: some View {
        // `List` stays the root container across every load state — not just
        // `.loaded` — so the container backing the large title never swaps
        // out for a plain centered `VStack` mid-transition (which used to
        // drop the "Projects" title down the screen) and so the
        // `.refreshable` task, owned by this `List`, never gets torn down
        // and cancelled by a state change mid-refresh.
        content
            .projectsListStyle()
            .refreshable { await viewModel.load() }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingCreateProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Project")
                }
            }
            .sheet(isPresented: $isShowingCreateProject, onDismiss: {
                Task { await viewModel.load() }
            }) {
                CreateProjectSheetView(viewModel: makeCreateProjectViewModel())
            }
            .sheet(item: $editingProject, onDismiss: {
                Task { await viewModel.load() }
            }) { project in
                EditProjectSheetView(viewModel: makeEditProjectViewModel(project))
            }
            .confirmationDialog(
                deleteConfirmationMessage,
                isPresented: Binding(
                    get: { projectPendingDelete != nil },
                    set: {
                        isPresented in if !isPresented {
                            projectPendingDelete = nil
                        }
                    },
                ),
                titleVisibility: .visible,
            ) {
                if let projectPendingDelete {
                    Button("Delete Project", role: .destructive) {
                        Task { await viewModel.deleteProject(projectPendingDelete) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await viewModel.load()
            }
    }

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
                ProjectsStatusView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load projects",
                    message: message,
                ) {
                    Task { await viewModel.load() }
                }
                .padding(.top, VikunjaSpacing.xxl)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            case .loaded where viewModel.rootNodes.isEmpty:
                ProjectsStatusView(
                    systemImage: "folder.badge.plus",
                    title: "No projects yet",
                    message: "Projects you create on your Vikunja instance will show up here.",
                )
                .padding(.top, VikunjaSpacing.xxl)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            case .loaded:
                Section {
                    ForEach(Self.flatten(viewModel.rootNodes, expandedProjectIDs: expandedProjectIDs)) { row in
                        ProjectRow(
                            project: row.node.project,
                            taskSummary: viewModel.taskSummaries[row.node.id],
                            level: row.level,
                            hasChildren: !row.node.children.isEmpty,
                            isExpanded: expandedProjectIDs.contains(row.node.id),
                            onSelect: { router.push(.projectOverview(row.node)) },
                            onToggleExpand: { toggleExpanded(row.node.id) },
                            onEdit: { editingProject = $0 },
                            onDelete: { projectPendingDelete = row.node },
                        )
                    }
                } header: {
                    Text(Self.countText(for: viewModel.rootNodes))
                        .font(VikunjaFont.subheadline)
                        .foregroundStyle(VikunjaColor.textSecondary)
                        .textCase(nil)
                }
            }
        }
    }

    private var deleteConfirmationMessage: String {
        let hasChildren = projectPendingDelete?.children.isEmpty == false
        return hasChildren
            ? "This permanently deletes the project, its subprojects, and all their tasks."
            : "This permanently deletes the project and all its tasks."
    }

    private func toggleExpanded(_ id: Int) {
        withAnimation(.snappy) {
            if expandedProjectIDs.contains(id) {
                expandedProjectIDs.remove(id)
            } else {
                expandedProjectIDs.insert(id)
            }
        }
    }

    private static func countText(for nodes: [ProjectNode]) -> String {
        let count = totalCount(in: nodes)
        return count == 1 ? "1 project" : "\(count) projects"
    }

    private static func totalCount(in nodes: [ProjectNode]) -> Int {
        nodes.reduce(0) { $0 + 1 + totalCount(in: $1.children) }
    }

    private static func flatten(
        _ nodes: [ProjectNode],
        level: Int = 0,
        expandedProjectIDs: Set<Int>,
    ) -> [ProjectDisplayRow] {
        nodes.flatMap { node -> [ProjectDisplayRow] in
            var rows = [ProjectDisplayRow(node: node, level: level)]
            if expandedProjectIDs.contains(node.id) {
                rows += flatten(node.children, level: level + 1, expandedProjectIDs: expandedProjectIDs)
            }
            return rows
        }
    }
}

private struct ProjectDisplayRow: Identifiable {
    let node: ProjectNode
    let level: Int
    var id: Int {
        node.id
    }
}

/// A single row: a color swatch (from the project's `hexColor`, falling back
/// to the brand color when unset), title, a task-completion progress bar +
/// `done/total` count when the project has tasks, and — only when the project
/// has children — a disclosure chevron. Tapping the row itself opens that
/// project's overview; the chevron is its own tap target that only
/// expands/collapses the children, so opening a parent project doesn't
/// require first collapsing it.
private struct ProjectRow: View {
    let project: Project
    let taskSummary: ProjectTaskSummary?
    let level: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpand: () -> Void
    let onEdit: (Project) -> Void
    let onDelete: () -> Void

    private var swatchColor: Color {
        Color(vikunjaHex: project.hexColor) ?? VikunjaColor.brandPrimary
    }

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm + VikunjaSpacing.xxs) {
            RoundedRectangle(cornerRadius: VikunjaRadius.sm, style: .continuous)
                .fill(swatchColor.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(swatchColor)
                        .frame(width: 12, height: 12)
                }

            VStack(alignment: .leading, spacing: VikunjaSpacing.xs) {
                Text(project.title)
                    .font(VikunjaFont.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // The second line always occupies the same height, whether or
                // not this project's task summary has arrived yet — its own
                // request lands after the tree renders, and letting the row
                // grow when it does shifts every row below it. Until then a
                // redacted skeleton holds the space; a project that turns out
                // to have no tasks keeps the line as "No tasks" rather than
                // collapsing it (which would shift the row a second time).
                Group {
                    if let taskSummary {
                        if taskSummary.total > 0 {
                            ProjectProgressCount(summary: taskSummary, color: swatchColor)
                        } else {
                            Text("No tasks")
                                .font(VikunjaFont.caption)
                                .foregroundStyle(VikunjaColor.textTertiary)
                        }
                    } else {
                        ProjectProgressCount(
                            summary: ProjectTaskSummary(done: 0, total: 1),
                            color: swatchColor,
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: taskSummary)
            }

            Spacer(minLength: VikunjaSpacing.sm)

            if hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VikunjaColor.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            }
        }
        .padding(.leading, CGFloat(level) * VikunjaSpacing.lg)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: { onEdit(project) })
            // `role: .destructive` alone renders blue here, not red: the tab
            // bar's `.tint(VikunjaColor.brandPrimary)` leaks into the context
            // menu and overrides the role's tint. Pin it back to danger.
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                .tint(VikunjaColor.Semantic.danger)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(project.title)
    }
}

/// The design's per-project progress affordance: a slim completion bar
/// capped at 120pt wide, followed by a `done/total` count.
private struct ProjectProgressCount: View {
    let summary: ProjectTaskSummary
    let color: Color

    var body: some View {
        HStack(spacing: VikunjaSpacing.sm) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VikunjaColor.Surface.field)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * summary.fraction)
                }
            }
            .frame(width: 120, height: 4)

            Text("\(summary.done)/\(summary.total)")
                .font(VikunjaFont.caption)
                .foregroundStyle(VikunjaColor.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.done) of \(summary.total) tasks completed")
    }
}

/// `.insetGrouped` is iOS/watchOS-only, but this package also builds for
/// macOS to run its tests — falls back to the default style there.
private extension View {
    @ViewBuilder
    func projectsListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}

/// Shared empty/error state layout for the projects list.
private struct ProjectsStatusView: View {
    let systemImage: String
    let title: String
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: VikunjaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
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
