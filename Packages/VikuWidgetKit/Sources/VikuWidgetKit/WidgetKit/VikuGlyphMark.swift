// `.accessoryCircular` and `ControlWidget` are iOS Lock Screen / Control
// Center features; `os(iOS)` keeps this out of the macOS build.
#if canImport(WidgetKit) && os(iOS)
import SwiftUI

/// The Viku app glyph, drawn as vector shapes rather than loaded from an
/// asset — a bundled `Image` silently fails to render inside a widget or
/// control process. A solid rounded square with the checkmark, the accent
/// dot, and a small "+" all knocked out via `destinationOut`: cutting solid
/// shapes out (rather than filling them a color) is also what survives the
/// vibrant monochrome material iOS forces onto Lock Screen accessories and
/// Control Center controls, the way Todoist's glyph does.
///
/// The "+" marks this as the "add a task" action specifically — it's the
/// glyph behind the Lock Screen accessory (`QuickAddWidget`), the only place
/// this glyph appears now that the plain "Open Viku" `GlyphWidget` has been
/// folded into it. **Not** used by the Control Center control
/// (`QuickAddControl`) — a control's icon is rasterized into a template
/// image the system tints per context, and a custom view built from
/// `GeometryReader` + blend modes can't be captured that way (it renders as
/// a "?" placeholder), so that one stays a plain SF Symbol. Scales to
/// whatever square it's given.
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
                        GlyphPlus()
                            .stroke(style: StrokeStyle(lineWidth: side * 0.09, lineCap: .round))
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

/// The small "add" mark knocked out of the glyph's bottom-right corner.
private struct GlyphPlus: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let ox = rect.minX + (rect.width - side) / 2
        let oy = rect.minY + (rect.height - side) / 2
        func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: ox + fx * side, y: oy + fy * side)
        }
        let cx: CGFloat = 0.775, cy: CGFloat = 0.775, arm: CGFloat = 0.105
        var path = Path()
        path.move(to: p(cx - arm, cy))
        path.addLine(to: p(cx + arm, cy))
        path.move(to: p(cx, cy - arm))
        path.addLine(to: p(cx, cy + arm))
        return path
    }
}
#endif
