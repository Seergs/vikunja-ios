import Foundation
import Testing
@testable import VikunjaCore

struct TodayDigestTests {
    private static let calendar = Calendar.current
    private static let now = Date()
    private static let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
    private static let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
    private static let laterToday = calendar.date(byAdding: .hour, value: 1, to: now)!
    private static let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!

    private func digest(_ tasks: [VikunjaTask]) -> TodayDigest {
        TodayDigest(tasks: tasks, now: Self.now, calendar: Self.calendar)
    }

    @Test
    func groupsTasksIntoOverdueTodayAndUpcoming() {
        let overdue = VikunjaTask(id: 1, title: "Overdue", dueDate: Self.yesterday, projectID: 1)
        let today = VikunjaTask(id: 2, title: "Today", dueDate: Self.laterToday, projectID: 1)
        let upcoming = VikunjaTask(id: 3, title: "Upcoming", dueDate: Self.nextWeek, projectID: 1)

        let result = digest([upcoming, today, overdue])

        #expect(result.overdue.map(\.id) == [1])
        #expect(result.today.map(\.id) == [2])
        #expect(result.upcoming.map(\.id) == [3])
    }

    @Test
    func excludesTasksWithNoDueDate() {
        let result = digest([VikunjaTask(id: 1, title: "Someday", projectID: 1)])

        #expect(result.allTasks.isEmpty)
    }

    @Test
    func dropsADoneOverdueTaskFromEveryBucket() {
        let doneOverdue = VikunjaTask(id: 1, title: "Done", isDone: true, dueDate: Self.yesterday, projectID: 1)

        #expect(digest([doneOverdue]).allTasks.isEmpty)
    }

    @Test
    func keepsATaskDoneTodayInTheTodayBucket() {
        let doneToday = VikunjaTask(id: 1, title: "Done today", isDone: true, dueDate: Self.laterToday, projectID: 1)

        #expect(digest([doneToday]).today.map(\.id) == [1])
    }

    @Test
    func sortsEachBucketByAscendingDueDateThenID() {
        let overdueOlder = VikunjaTask(id: 1, title: "Older", dueDate: Self.twoDaysAgo, projectID: 1)
        let overdueNewer = VikunjaTask(id: 2, title: "Newer", dueDate: Self.yesterday, projectID: 1)
        let todayLater = VikunjaTask(
            id: 3, title: "Later", dueDate: Self.calendar.date(byAdding: .hour, value: 2, to: Self.now)!, projectID: 1
        )
        let todayEarlier = VikunjaTask(id: 4, title: "Earlier", dueDate: Self.laterToday, projectID: 1)

        let result = digest([overdueNewer, overdueOlder, todayLater, todayEarlier])

        #expect(result.overdue.map(\.id) == [1, 2])
        #expect(result.today.map(\.id) == [4, 3])
    }

    @Test
    func breaksDueDateTiesByID() {
        let higher = VikunjaTask(id: 5, title: "Higher", dueDate: Self.laterToday, projectID: 1)
        let lower = VikunjaTask(id: 2, title: "Lower", dueDate: Self.laterToday, projectID: 1)

        #expect(digest([higher, lower]).today.map(\.id) == [2, 5])
    }

    @Test
    func pendingCountIgnoresDoneTasks() {
        let pending = VikunjaTask(id: 1, title: "Pending", dueDate: Self.laterToday, projectID: 1)
        let doneToday = VikunjaTask(id: 2, title: "Done", isDone: true, dueDate: Self.laterToday, projectID: 1)

        #expect(digest([pending, doneToday]).pendingCount == 1)
    }

    @Test
    func bucketForClassifiesASingleTask() {
        let task = VikunjaTask(id: 1, title: "T", dueDate: Self.nextWeek, projectID: 1)

        #expect(TaskDueBucket.bucket(for: task, now: Self.now, calendar: Self.calendar) == .upcoming)
    }
}
