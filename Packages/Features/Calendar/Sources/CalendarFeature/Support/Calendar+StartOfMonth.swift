import Foundation

extension Calendar {
    /// Start of day of the first of the month containing `date` — the anchor
    /// `CalendarView` steps forward/back by whole months.
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}
