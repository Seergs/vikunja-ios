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
}
