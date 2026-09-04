import Foundation

public extension Calendar {
    /// Start of day of the first of the month containing `date` — the anchor
    /// the Calendar screen and widget step forward/back by whole months.
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}
