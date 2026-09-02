// Controls are an iOS Control Center / Lock Screen feature; `os(iOS)` keeps
// this out of the macOS build, where `ControlWidget` needs a far newer floor
// than the package's.
#if canImport(WidgetKit) && os(iOS)
import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center / Lock Screen / Action Button control that opens the app's
/// quick-add task sheet, via `QuickAddControlIntent`. Add `QuickAddControl()`
/// to the widget extension's `WidgetBundle` (behind an iOS 18 availability
/// check, since the package floor is iOS 17).
@available(iOS 18.0, *)
public struct QuickAddControl: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: VikuWidgetConfig.quickAddControlKind) {
            ControlWidgetButton(action: QuickAddControlIntent()) {
                Label("Add Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Task")
        .description("Open Viku's quick-add sheet.")
    }
}
#endif
