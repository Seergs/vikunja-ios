//
//  VikuApp.swift
//  Viku
//
//  Created by Sergio Suárez álvarez on 24/08/26.
//

import SwiftUI

@main
struct VikuApp: App {
    private let container = AppContainer()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .onChange(of: scenePhase) { _, phase in
            // Refresh the Today widget's shared snapshot whenever the app
            // leaves the foreground — the user may have just added or
            // completed a task. The app fetches with its own credentials and
            // writes the App Group cache the widget renders, so this works
            // even where the widget can't read the keychain itself.
            if phase == .background {
                Task { await container.refreshTodayWidgetSnapshot() }
            }
        }
    }
}
