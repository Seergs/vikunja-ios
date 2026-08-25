import SwiftUI

/// Placeholder landing screen for the Settings tab. Real content (account
/// switcher, preferences, sign-out) isn't built yet.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title2)
        }
        .padding()
        .navigationTitle("Settings")
    }
}
