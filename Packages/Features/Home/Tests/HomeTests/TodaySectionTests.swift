import Foundation
@testable import Home
import Testing
import VikunjaCore

struct TodaySectionTests {
    private static let calendar = Calendar.current
    /// A fixed reference instant, so bucketing never depends on the wall clock
    /// (a "later today" time built from `Date()` crosses midnight when the
    /// suite runs late in the evening — see the CI flake this replaced).
    private static let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) ?? Date()
    private static let startOfToday = calendar.startOfDay(for: now)

    private static func today(hour: Int) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: startOfToday) ?? startOfToday
    }

    private static func days(_ value: Int) -> Date {
        calendar.date(byAdding: .day, value: value, to: now) ?? now
    }

    private static let yesterday = days(-1)
    private static let laterToday = today(hour: 13)
    private static let nextWeek = days(7)

    private static func sections(_ tasks: [VikunjaTask], filter: TodayFilter) -> [TodaySection] {
        TodaySection.sections(from: tasks, filter: filter, now: now)
    }

    @Test
    func `groups tasks into overdue today and upcoming`() {
        let overdueTask = VikunjaTask(id: 1, title: "Overdue", dueDate: Self.yesterday, projectID: 1)
        let todayTask = VikunjaTask(id: 2, title: "Today", dueDate: Self.laterToday, projectID: 1)
        let upcomingTask = VikunjaTask(id: 3, title: "Upcoming", dueDate: Self.nextWeek, projectID: 1)

        let sections = Self.sections([overdueTask, todayTask, upcomingTask], filter: .all)

        #expect(sections.map(\.title) == ["Overdue", "Today", "Upcoming"])
        #expect(sections[0].tasks.map(\.id) == [1])
        #expect(sections[1].tasks.map(\.id) == [2])
        #expect(sections[2].tasks.map(\.id) == [3])
    }

    @Test
    func `excludes tasks with no due date`() {
        let noDueDate = VikunjaTask(id: 1, title: "Someday", projectID: 1)

        #expect(Self.sections([noDueDate], filter: .all).isEmpty)
    }

    @Test
    func `excludes A done task from the overdue section`() {
        let doneOverdue = VikunjaTask(id: 1, title: "Done", isDone: true, dueDate: Self.yesterday, projectID: 1)

        // Done + overdue drops out of every bucket entirely, rather than
        // showing as an overdue item — matching the mock's own behavior.
        #expect(Self.sections([doneOverdue], filter: .all).isEmpty)
    }

    @Test
    func `a task done today still shows in the today section`() {
        let doneToday = VikunjaTask(id: 1, title: "Done today", isDone: true, dueDate: Self.laterToday, projectID: 1)

        let sections = Self.sections([doneToday], filter: .all)

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections[0].tasks.map(\.id) == [1])
    }

    @Test
    func `sorts tasks within each section by ascending due date`() {
        let overdueTwoDaysAgo = VikunjaTask(id: 1, title: "Overdue, older", dueDate: Self.days(-2), projectID: 1)
        let overdueYesterday = VikunjaTask(id: 2, title: "Overdue, newer", dueDate: Self.yesterday, projectID: 1)
        let laterTonight = VikunjaTask(id: 3, title: "Today, later", dueDate: Self.today(hour: 20), projectID: 1)
        let earlierToday = VikunjaTask(id: 4, title: "Today, earlier", dueDate: Self.today(hour: 9), projectID: 1)

        let sections = Self.sections(
            [overdueYesterday, overdueTwoDaysAgo, laterTonight, earlierToday],
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

        let sections = Self.sections([higherID, lowerID], filter: .all)

        #expect(sections[0].tasks.map(\.id) == [2, 5])
    }

    @Test
    func `filtering narrows to only the selected bucket`() {
        let overdueTask = VikunjaTask(id: 1, title: "Overdue", dueDate: Self.yesterday, projectID: 1)
        let todayTask = VikunjaTask(id: 2, title: "Today", dueDate: Self.laterToday, projectID: 1)

        let sections = Self.sections([overdueTask, todayTask], filter: .today)

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections[0].tasks.map(\.id) == [2])
    }
}
