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
    @State private var expandedProjectIDs: Set<Int> = []

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
            .task {
                await viewModel.load()
                if expandedProjectIDs.isEmpty {
                    expandedProjectIDs = Self.parentIDs(in: viewModel.rootNodes)
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
                ProjectsStatusView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load projects",
                    message: message
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
                    message: "Projects you create on your Vikunja instance will show up here."
                )
                .padding(.top, VikunjaSpacing.xxl)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            case .loaded:
                Section {
                    ForEach(Self.flatten(viewModel.rootNodes, expandedProjectIDs: expandedProjectIDs)) { row in
                        ProjectRow(
                            project: row.node.project,
                            level: row.level,
                            hasChildren: !row.node.children.isEmpty,
                            isExpanded: expandedProjectIDs.contains(row.node.id),
                            onSelect: { router.push(.projectOverview(row.node)) },
                            onToggleExpand: { toggleExpanded(row.node.id) }
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

    private func toggleExpanded(_ id: Int) {
        withAnimation(.snappy) {
            if expandedProjectIDs.contains(id) {
                expandedProjectIDs.remove(id)
            } else {
                expandedProjectIDs.insert(id)
            }
        }
    }

    /// All ids that have at least one child, so the tree starts fully
    /// expanded — nothing is hidden from the user by default.
    private static func parentIDs(in nodes: [ProjectNode]) -> Set<Int> {
        nodes.reduce(into: Set<Int>()) { ids, node in
            guard !node.children.isEmpty else { return }
            ids.insert(node.id)
            ids.formUnion(parentIDs(in: node.children))
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
        expandedProjectIDs: Set<Int>
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
    var id: Int { node.id }
}

/// A single row: a color swatch (from the project's `hexColor`, falling back
/// to the brand color when unset), title, and — only when the project has
/// children — a disclosure chevron. Tapping the row itself opens that
/// project's overview; the chevron is its own tap target that only
/// expands/collapses the children, so opening a parent project doesn't
/// require first collapsing it.
private struct ProjectRow: View {
    let project: Project
    let level: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpand: () -> Void

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

            Text(project.title)
                .font(VikunjaFont.body)
                .fontWeight(.semibold)
                .lineLimit(1)

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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(project.title)
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
