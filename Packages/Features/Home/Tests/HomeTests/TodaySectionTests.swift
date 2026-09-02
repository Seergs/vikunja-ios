import Foundation
@testable import Home
import Testing
import VikunjaCore

struct TodaySectionTests {
    private static let calendar = Calendar.current
    private static let now = Date()
    private static let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
    private static let laterToday = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
    private static let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now

    @Test
    func `groups tasks into overdue today and upcoming`() {
        let overdueTask = VikunjaTask(id: 1, title: "Overdue", dueDate: Self.yesterday, projectID: 1)
        let todayTask = VikunjaTask(id: 2, title: "Today", dueDate: Self.laterToday, projectID: 1)
        let upcomingTask = VikunjaTask(id: 3, title: "Upcoming", dueDate: Self.nextWeek, projectID: 1)

        let sections = TodaySection.sections(from: [overdueTask, todayTask, upcomingTask], filter: .all)

        #expect(sections.map(\.title) == ["Overdue", "Today", "Upcoming"])
        #expect(sections[0].tasks.map(\.id) == [1])
        #expect(sections[1].tasks.map(\.id) == [2])
        #expect(sections[2].tasks.map(\.id) == [3])
    }

    @Test
    func `excludes tasks with no due date`() {
        let noDueDate = VikunjaTask(id: 1, title: "Someday", projectID: 1)

        let sections = TodaySection.sections(from: [noDueDate], filter: .all)

        #expect(sections.isEmpty)
    }

    @Test
    func `excludes A done task from the overdue section`() {
        let doneOverdue = VikunjaTask(id: 1, title: "Done", isDone: true, dueDate: Self.yesterday, projectID: 1)

        let sections = TodaySection.sections(from: [doneOverdue], filter: .all)

        // Done + overdue drops out of every bucket entirely, rather than
        // showing as an overdue item — matching the mock's own behavior.
        #expect(sections.isEmpty)
    }

    @Test
    func `a task done today still shows in the today section`() {
        let doneToday = VikunjaTask(id: 1, title: "Done today", isDone: true, dueDate: Self.laterToday, projectID: 1)

        let sections = TodaySection.sections(from: [doneToday], filter: .all)

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections[0].tasks.map(\.id) == [1])
    }

    @Test
    func `sorts tasks within each section by ascending due date`() throws {
        let overdueTwoDaysAgo = try VikunjaTask(
            id: 1,
            title: "Overdue, older",
            dueDate: #require(Self.calendar.date(byAdding: .day, value: -2, to: Self.now)),
            projectID: 1,
        )
        let overdueYesterday = VikunjaTask(id: 2, title: "Overdue, newer", dueDate: Self.yesterday, projectID: 1)
        let laterTonight = try VikunjaTask(
            id: 3,
            title: "Today, later",
            dueDate: #require(Self.calendar.date(byAdding: .hour, value: 2, to: Self.now)),
            projectID: 1,
        )
        let earlierToday = VikunjaTask(id: 4, title: "Today, earlier", dueDate: Self.laterToday, projectID: 1)

        let sections = TodaySection.sections(
            from: [overdueYesterday, overdueTwoDaysAgo, laterTonight, earlierToday],
            filter: .all,
        )

        #expect(sections[0].tasks.map(\.id) == [1, 2])
        #expect(sections[1].tasks.map(\.id) == [4, 3])
    }

    @Test
    func `breaks due date ties by id`() {
        let sameDueDate = Self.laterToday
        let higherID = VikunjaTask(id: 5, title: "Higher id", dueDate: sameDueDate, projectID: 1)
        let lowerID = VikunjaTask(id: 2, title: "Lower id", dueDate: sameDueDate, projectID: 1)

        let sections = TodaySection.sections(from: [higherID, lowerID], filter: .all)

        #expect(sections[0].tasks.map(\.id) == [2, 5])
    }

    @Test
    func `filtering narrows to only the selected bucket`() {
        let overdueTask = VikunjaTask(id: 1, title: "Overdue", dueDate: Self.yesterday, projectID: 1)
        let todayTask = VikunjaTask(id: 2, title: "Today", dueDate: Self.laterToday, projectID: 1)
        let tasks = [overdueTask, todayTask]

        let sections = TodaySection.sections(from: tasks, filter: .today)

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections[0].tasks.map(\.id) == [2])
    }
}
