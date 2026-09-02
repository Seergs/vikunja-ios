#if canImport(WidgetKit)
import SwiftUI
import WidgetKit

/// The "Today" home-screen widget: overdue / due-today / upcoming tasks from
/// the active Vikunja account. Add `TodayWidget()` to the extension's
/// `WidgetBundle`.
public struct TodayWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: VikuWidgetConfig.todayWidgetKind, provider: TodayTimelineProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Tasks that are overdue, due today, or coming up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // We control the inset ourselves (`TodayWidgetView` adds its own
        // padding) so the content isn't double-margined.
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, state: .content(.placeholder))
    TodayEntry(date: .now, state: .notConnected)
}
#endif
