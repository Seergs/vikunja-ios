import SwiftUI
import VikunjaCore
import VikunjaDesignSystem

/// The Projects tab's list screen: a flattened, indented rendering of
/// `ProjectsListViewModel.rootNodes` (a parent/child tree keyed by
/// `parentProjectID`), with per-project expand/collapse.
struct ProjectsView: View {
    @Bindable var viewModel: ProjectsListViewModel
    @State private var expandedProjectIDs: Set<Int> = []

    var body: some View {
        content
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
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failure(message):
            ProjectsStatusView(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load projects",
                message: message
            ) {
                Task { await viewModel.load() }
            }
        case .loaded where viewModel.rootNodes.isEmpty:
            ProjectsStatusView(
                systemImage: "folder.badge.plus",
                title: "No projects yet",
                message: "Projects you create on your Vikunja instance will show up here."
            )
        case .loaded:
            List {
                Section {
                    ForEach(Self.flatten(viewModel.rootNodes, expandedProjectIDs: expandedProjectIDs)) { row in
                        ProjectRow(
                            project: row.node.project,
                            level: row.level,
                            hasChildren: !row.node.children.isEmpty,
                            isExpanded: expandedProjectIDs.contains(row.node.id)
                        ) {
                            toggleExpanded(row.node.id)
                        }
                    }
                } header: {
                    Text(Self.countText(for: viewModel.rootNodes))
                        .font(VikunjaFont.subheadline)
                        .foregroundStyle(VikunjaColor.textSecondary)
                        .textCase(nil)
                }
            }
            .projectsListStyle()
            .refreshable { await viewModel.load() }
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
/// children — a disclosure chevron.
private struct ProjectRow: View {
    let project: Project
    let level: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

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
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VikunjaColor.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .padding(.leading, CGFloat(level) * VikunjaSpacing.lg)
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasChildren else { return }
            onToggle()
        }
        .accessibilityAddTraits(hasChildren ? [.isButton] : [])
        .accessibilityLabel(project.title)
        .accessibilityValue(hasChildren ? (isExpanded ? "Expanded" : "Collapsed") : "")
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
