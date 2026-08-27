import Foundation
import Testing
import VikunjaCore
@testable import Home

struct TodaySectionTests {
    private static let calendar = Calendar.current
    private static let now = Date()
    private static let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
    private static let laterToday = calendar.date(byAdding: .hour, value: 1, to: now)!
    private static let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!

    @Test
    func groupsTasksIntoOverdueTodayAndUpcoming() {
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
    func excludesTasksWithNoDueDate() {
        let noDueDate = VikunjaTask(id: 1, title: "Someday", projectID: 1)

        let sections = TodaySection.sections(from: [noDueDate], filter: .all)

        #expect(sections.isEmpty)
    }

    @Test
    func excludesADoneTaskFromTheOverdueSection() {
        let doneOverdue = VikunjaTask(id: 1, title: "Done", isDone: true, dueDate: Self.yesterday, projectID: 1)

        let sections = TodaySection.sections(from: [doneOverdue], filter: .all)

        // Done + overdue drops out of every bucket entirely, rather than
        // showing as an overdue item — matching the mock's own behavior.
        #expect(sections.isEmpty)
    }

    @Test
    func aTaskDoneTodayStillShowsInTheTodaySection() {
        let doneToday = VikunjaTask(id: 1, title: "Done today", isDone: true, dueDate: Self.laterToday, projectID: 1)

        let sections = TodaySection.sections(from: [doneToday], filter: .all)

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections[0].tasks.map(\.id) == [1])
    }

    @Test
    func sortsTasksWithinEachSectionByAscendingDueDate() {
        let overdueTwoDaysAgo = VikunjaTask(
            id: 1,
            title: "Overdue, older",
            dueDate: Self.calendar.date(byAdding: .day, value: -2, to: Self.now)!,
            projectID: 1
        )
        let overdueYesterday = VikunjaTask(id: 2, title: "Overdue, newer", dueDate: Self.yesterday, projectID: 1)
        let laterTonight = VikunjaTask(
            id: 3,
            title: "Today, later",
            dueDate: Self.calendar.date(byAdding: .hour, value: 2, to: Self.now)!,
            projectID: 1
        )
        let earlierToday = VikunjaTask(id: 4, title: "Today, earlier", dueDate: Self.laterToday, projectID: 1)

        let sections = TodaySection.sections(
            from: [overdueYesterday, overdueTwoDaysAgo, laterTonight, earlierToday],
            filter: .all
        )

        #expect(sections[0].tasks.map(\.id) == [1, 2])
        #expect(sections[1].tasks.map(\.id) == [4, 3])
    }

    @Test
    func breaksDueDateTiesById() {
        let sameDueDate = Self.laterToday
        let higherID = VikunjaTask(id: 5, title: "Higher id", dueDate: sameDueDate, projectID: 1)
        let lowerID = VikunjaTask(id: 2, title: "Lower id", dueDate: sameDueDate, projectID: 1)

        let sections = TodaySection.sections(from: [higherID, lowerID], filter: .all)

        #expect(sections[0].tasks.map(\.id) == [2, 5])
    }

    @Test
    func filteringNarrowsToOnlyTheSelectedBucket() {
        let overdueTask = VikunjaTask(id: 1, title: "Overdue", dueDate: Self.yesterday, projectID: 1)
        let todayTask = VikunjaTask(id: 2, title: "Today", dueDate: Self.laterToday, projectID: 1)
        let tasks = [overdueTask, todayTask]

        let sections = TodaySection.sections(from: tasks, filter: .today)

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections[0].tasks.map(\.id) == [2])
    }
}
