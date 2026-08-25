import SwiftUI

/// Placeholder landing screen for the Projects tab. Real content (the project
/// list, creation, reordering) isn't built yet.
struct ProjectsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Projects")
                .font(.title2)
        }
        .padding()
        .navigationTitle("Projects")
    }
}
