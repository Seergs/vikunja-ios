import Foundation

/// Which due-date bucket a task falls into on the "Today" view — the pure
/// grouping rule shared by `Features/Home`'s screen and the Today widget, so
/// both stay in sync without the widget depending on a feature module.
public enum TaskDueBucket: String, Sendable, CaseIterable, Hashable, Codable {
    case overdue
    case today
    case upcoming

    /// The bucket `task` belongs in relative to `now`, or `nil` if it doesn't
    /// belong on the Today view at all (no due date, or done + overdue).
    ///
    /// A task with no due date never appears on Today — only inside its own
    /// project. A done task whose due date is in the past drops out of every
    /// bucket rather than lingering as "overdue"; a task due today still shows
    /// (in `.today`) even once completed.
    public static func bucket(
        for task: VikunjaTask,
        now: Date = Date(),
        calendar: Calendar = .current,
    ) -> TaskDueBucket? {
        guard let dueDate = task.dueDate else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return nil
        }

        if dueDate < startOfToday {
            return task.isDone ? nil : .overdue
        }
        if dueDate < startOfTomorrow {
            return .today
        }
        return .upcoming
    }
}

/// The Today view's tasks already split into their three due-date buckets and
/// sorted within each — ascending by due date, ties broken by task id. Built
/// once from a flat task list and consumed by both the Home screen and the
/// widget.
public struct TodayDigest: Sendable, Hashable {
    public let overdue: [VikunjaTask]
    public let today: [VikunjaTask]
    public let upcoming: [VikunjaTask]

    public init(overdue: [VikunjaTask], today: [VikunjaTask], upcoming: [VikunjaTask]) {
        self.overdue = overdue
        self.today = today
        self.upcoming = upcoming
    }

    public init(
        tasks: [VikunjaTask],
        now: Date = Date(),
        calendar: Calendar = .current,
    ) {
        var overdue: [VikunjaTask] = []
        var today: [VikunjaTask] = []
        var upcoming: [VikunjaTask] = []

        for task in tasks {
            switch TaskDueBucket.bucket(for: task, now: now, calendar: calendar) {
            case .overdue: overdue.append(task)
            case .today: today.append(task)
            case .upcoming: upcoming.append(task)
            case nil: continue
            }
        }

        self.overdue = Self.sortedByDueDate(overdue)
        self.today = Self.sortedByDueDate(today)
        self.upcoming = Self.sortedByDueDate(upcoming)
    }

    /// Every bucketed task in display order (overdue, then today, then
    /// upcoming) — for widget families that show one flat list.
    public var allTasks: [VikunjaTask] {
        overdue + today + upcoming
    }

    public var pendingCount: Int {
        (overdue + today + upcoming).lazy.filter { !$0.isDone }.count
    }

    public func tasks(in bucket: TaskDueBucket) -> [VikunjaTask] {
        switch bucket {
        case .overdue: overdue
        case .today: today
        case .upcoming: upcoming
        }
    }

    private static func sortedByDueDate(_ tasks: [VikunjaTask]) -> [VikunjaTask] {
        tasks.sorted { lhs, rhs in
            guard let lhsDate = lhs.dueDate, let rhsDate = rhs.dueDate else { return false }
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.id < rhs.id
        }
    }
}
