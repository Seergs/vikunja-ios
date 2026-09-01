import Testing
import VikunjaCore
@testable import VikunjaDesignSystem

@Suite("ProjectPickerTree")
struct ProjectPickerTreeTests {
    private func project(_ id: Int, parent: Int? = nil, position: Double = 0, title: String? = nil) -> Project {
        Project(id: id, title: title ?? "Project \(id)", parentProjectID: parent, position: position)
    }

    @Test("Arranges projects into a parent/child tree ordered by position")
    func buildsOrderedTree() {
        let projects = [
            project(1, position: 2),
            project(2, position: 1),
            project(3, parent: 1, position: 2),
            project(4, parent: 1, position: 1),
        ]

        let tree = ProjectPickerTree.tree(from: projects)

        #expect(tree.map(\.id) == [2, 1])
        #expect(tree[1].children.map(\.id) == [4, 3])
    }

    @Test("Nests to arbitrary depth")
    func nestsDeeply() {
        let projects = [
            project(1),
            project(2, parent: 1),
            project(3, parent: 2),
            project(4, parent: 3),
        ]

        let tree = ProjectPickerTree.tree(from: projects)

        #expect(tree[0].children[0].children[0].children[0].id == 4)
    }

    @Test("Drops a project and its whole subtree when excluded")
    func excludesSubtree() {
        let projects = [
            project(1),
            project(2, parent: 1),
            project(3, parent: 2),
            project(4),
        ]

        let tree = ProjectPickerTree.tree(from: projects, excludingSubtreeOf: 1)

        #expect(tree.map(\.id) == [4])
    }

    @Test("Survives a cyclic parentProjectID")
    func toleratesCycle() {
        let projects = [
            project(1, parent: 2),
            project(2, parent: 1),
        ]

        let tree = ProjectPickerTree.tree(from: projects)

        #expect(tree.isEmpty)
    }

    @Test("flatMatches filters by title, case-insensitively, ignoring hierarchy")
    func flatMatchesFilters() {
        let projects = [
            project(1, title: "Work"),
            project(2, parent: 1, title: "Workout plan"),
            project(3, title: "Home"),
        ]

        let matches = ProjectPickerTree.flatMatches(projects, query: "work")

        #expect(matches.map(\.id) == [1, 2])
    }

    @Test("flatMatches honors the excluded subtree")
    func flatMatchesExcludesSubtree() {
        let projects = [
            project(1, title: "Work"),
            project(2, parent: 1, title: "Work sub"),
        ]

        #expect(ProjectPickerTree.flatMatches(projects, query: "work", excludingSubtreeOf: 1).isEmpty)
    }

    @Test("ancestorIDs walks from a project up to its root")
    func ancestorIDsWalkUp() {
        let projects = [
            project(1),
            project(2, parent: 1),
            project(3, parent: 2),
        ]

        #expect(ProjectPickerTree.ancestorIDs(of: 3, in: projects) == [1, 2])
        #expect(ProjectPickerTree.ancestorIDs(of: 1, in: projects).isEmpty)
        #expect(ProjectPickerTree.ancestorIDs(of: nil, in: projects).isEmpty)
    }
}
