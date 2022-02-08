import SwiftUI

@main
struct MembraneVideoroomDemoApp: App {
    @StateObject private var appState = AppController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .navigationTitle("Membrane Videoroom Demo")
        }
    }
}
