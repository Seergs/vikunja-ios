// `.accessoryCircular` is an iOS Lock Screen / StandBy family; `os(iOS)` keeps
// this out of the macOS build where that family is unavailable.
#if canImport(WidgetKit) && os(iOS)
import SwiftUI
import WidgetKit

/// A minimal Lock Screen / StandBy accessory widget: a single "+" that opens
/// the app's quick-add sheet — the Lock Screen counterpart of `QuickAddControl`
/// in Control Center. Static: no data, no network, never refreshes. Opens via
/// the `viku://quick-add` deep link rather than an App Intent, the same way
/// `TodayWidget` deep-links to `viku://today`. Add `QuickAddWidget()` to the
/// extension's `WidgetBundle`.
public struct QuickAddWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: VikunjaWidgetConfig.quickAddWidgetKind, provider: QuickAddTimelineProvider()) { _ in
            QuickAddWidgetView()
        }
        .configurationDisplayName("Quick Add")
        .description("Add a task in one tap.")
        .supportedFamilies([.accessoryCircular])
    }
}

public struct QuickAddEntry: TimelineEntry, Sendable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// One fixed entry, never reloaded — the widget has nothing to keep up to date.
public struct QuickAddTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in _: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date())
    }

    public func getSnapshot(in _: Context, completion: @escaping @Sendable (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: Date()))
    }

    public func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: Date())], policy: .never))
    }
}

struct QuickAddWidgetView: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .bold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "\(VikunjaWidgetConfig.urlScheme)://quick-add"))
            .containerBackground(for: .widget) {
                AccessoryWidgetBackground()
            }
    }
}

#Preview(as: .accessoryCircular) {
    QuickAddWidget()
} timeline: {
    QuickAddEntry(date: .now)
}
#endif
