//
//  vikunjaApp.swift
//  vikunja
//
//  Created by Sergio Suárez álvarez on 24/08/26.
//

import SwiftUI

@main
struct vikunjaApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
