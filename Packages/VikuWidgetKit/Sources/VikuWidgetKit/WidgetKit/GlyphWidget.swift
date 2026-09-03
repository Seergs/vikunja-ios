// `.accessoryCircular` is an iOS Lock Screen / StandBy family; `os(iOS)` keeps
// this out of the macOS build where that family is unavailable.
#if canImport(WidgetKit) && os(iOS)
import SwiftUI
import WidgetKit

/// A minimal Lock Screen / StandBy accessory widget: the app-icon glyph as a
/// one-tap launcher. Static: no data, no network, never refreshes. The glyph
/// (`VikuGlyphMark`) is drawn with SwiftUI shapes rather than loaded from an
/// asset — a bundled `Image` silently fails to render inside the widget
/// process. The rounded square is the solid silhouette; the checkmark and dot
/// are punched out with `destinationOut` so the vibrant monochrome material
/// iOS forces on Lock Screen widgets shows the wallpaper through them, the way
/// Todoist's does. Opens via the `viku://today` deep link, the same one
/// `TodayWidget` uses. Add `GlyphWidget()` to the extension's `WidgetBundle`.
public struct GlyphWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: VikuWidgetConfig.glyphWidgetKind, provider: GlyphTimelineProvider()) { _ in
            GlyphWidgetView()
        }
        .configurationDisplayName("Open Viku")
        .description("The Viku glyph as a one-tap shortcut.")
        .supportedFamilies([.accessoryCircular])
    }
}

public struct GlyphEntry: TimelineEntry, Sendable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// One fixed entry, never reloaded — the widget has nothing to keep up to date.
public struct GlyphTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in _: Context) -> GlyphEntry {
        GlyphEntry(date: Date())
    }

    public func getSnapshot(in _: Context, completion: @escaping @Sendable (GlyphEntry) -> Void) {
        completion(GlyphEntry(date: Date()))
    }

    public func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<GlyphEntry>) -> Void) {
        completion(Timeline(entries: [GlyphEntry(date: Date())], policy: .never))
    }
}

struct GlyphWidgetView: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                // Explicit disc: `AccessoryWidgetBackground` on its own doesn't
                // reliably show on the Lock Screen here, so draw the frosted
                // ring ourselves. Not accentable, so it stays a faint backing
                // rather than a bright fill.
                Circle().fill(.white.opacity(0.16))
                VikuGlyphMark()
                    .widgetAccentable()
                    .frame(width: side * 0.46, height: side * 0.46)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "\(VikuWidgetConfig.urlScheme)://today"))
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }
}

/// The Viku app glyph, drawn as vector shapes: a solid rounded square with the
/// checkmark and the dot knocked out via `destinationOut`. Scales to whatever
/// square it's given.
struct VikuGlyphMark: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            RoundedRectangle(cornerRadius: side * 0.235, style: .continuous)
                .overlay {
                    ZStack {
                        GlyphCheckmark()
                            .stroke(style: StrokeStyle(lineWidth: side * 0.125, lineCap: .round, lineJoin: .round))
                        Circle()
                            .frame(width: side * 0.11, height: side * 0.11)
                            .position(x: side * 0.23, y: side * 0.19)
                    }
                    .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct GlyphCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let ox = rect.minX + (rect.width - side) / 2
        let oy = rect.minY + (rect.height - side) / 2
        func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: ox + fx * side, y: oy + fy * side)
        }
        var path = Path()
        path.move(to: p(0.29, 0.52))
        path.addLine(to: p(0.44, 0.67))
        path.addLine(to: p(0.73, 0.31))
        return path
    }
}

#Preview(as: .accessoryCircular) {
    GlyphWidget()
} timeline: {
    GlyphEntry(date: .now)
}
#endif
