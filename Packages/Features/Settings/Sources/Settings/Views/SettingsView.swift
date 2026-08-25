import SwiftUI

/// Placeholder landing screen for the Settings tab. Real content (account
/// switcher, preferences) isn't built yet.
struct SettingsView: View {
    let onResetConnection: () -> Void
    @State private var isConfirmingReset = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title2)

            Button("Update API Token", role: .destructive) {
                isConfirmingReset = true
            }
            .padding(.top, 24)
        }
        .padding()
        .navigationTitle("Settings")
        .confirmationDialog(
            "This removes your saved connection so you can enter it again with a new token.",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Remove Connection", role: .destructive, action: onResetConnection)
            Button("Cancel", role: .cancel) {}
        }
    }
}
