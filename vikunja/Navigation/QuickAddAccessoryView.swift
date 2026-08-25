import SwiftUI

/// Floating accessory shown above the tab bar via `.tabViewBottomAccessory`,
/// which already gives its content the glass pill treatment — this view
/// supplies only the label and action. `onTap` is a no-op placeholder until a
/// Tasks feature exists to create a task from it.
struct QuickAddAccessoryView: View {
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            Label("Quick Add", systemImage: "plus")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }
}
