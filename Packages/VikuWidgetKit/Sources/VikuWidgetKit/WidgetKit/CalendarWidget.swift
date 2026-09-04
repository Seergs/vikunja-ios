#if canImport(WidgetKit)
import SwiftUI
import WidgetKit

/// The large month-grid home-screen widget: the current month with a status dot
/// per day for its pending projects, plus today's task list. Add
/// `CalendarWidget()` to the extension's `WidgetBundle`.
public struct CalendarWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: VikuWidgetConfig.calendarWidgetKind, provider: CalendarTimelineProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Calendar")
        .description("This month's tasks at a glance, with today's list.")
        .supportedFamilies([.systemLarge])
        // `CalendarWidgetView` adds its own padding so the grid isn't
        // double-margined.
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    CalendarWidget()
} timeline: {
    CalendarEntry(date: .now, state: .content(.placeholder))
    CalendarEntry(date: .now, state: .notConnected)
}
#endif
