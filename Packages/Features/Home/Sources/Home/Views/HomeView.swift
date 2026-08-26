import SwiftUI

/// Placeholder landing screen shown once a connection has been set up. Real
/// content (tasks, projects, etc.) isn't built yet — this only confirms which
/// instance the app is connected to.
public struct HomeView: View {
    private let accountName: String

    public init(accountName: String) {
        self.accountName = accountName
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Connected to \(accountName)")
                .font(.title2)
        }
        .padding()
        .navigationTitle("Today")
    }
}
