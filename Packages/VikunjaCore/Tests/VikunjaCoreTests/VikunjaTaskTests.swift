import Testing
@testable import VikunjaCore

struct VikunjaTaskTests {
    @Test
    func defaultsToUnsetPriorityAndNoLabels() {
        let task = VikunjaTask(id: 1, title: "Buy coffee", projectID: 4)

        #expect(task.priority == .unset)
        #expect(task.labels.isEmpty)
        #expect(task.isDone == false)
    }

    @Test
    func defaultsToNoRelations() {
        let task = VikunjaTask(id: 1, title: "Buy coffee", projectID: 4)

        #expect(task.subtasks.isEmpty)
        #expect(task.dependsOn.isEmpty)
        #expect(task.blocks.isEmpty)
        #expect(task.isBlocked == false)
    }

    @Test
    func isBlockedWhenAnyDependsOnTaskIsNotDone() {
        let task = VikunjaTask(
            id: 1,
            title: "Ship release",
            projectID: 4,
            dependsOn: [
                TaskRelation(id: 2, title: "Write tests", isDone: true, projectID: 4),
                TaskRelation(id: 3, title: "Fix bug", isDone: false, projectID: 4),
            ]
        )

        #expect(task.isBlocked == true)
    }

    @Test
    func isNotBlockedWhenEveryDependsOnTaskIsDone() {
        let task = VikunjaTask(
            id: 1,
            title: "Ship release",
            projectID: 4,
            dependsOn: [TaskRelation(id: 2, title: "Write tests", isDone: true, projectID: 4)]
        )

        #expect(task.isBlocked == false)
    }
}
