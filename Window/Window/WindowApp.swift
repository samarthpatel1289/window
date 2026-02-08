import SwiftUI

@main
struct WindowApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    appState.attemptAutoConnect()
                }
        }
    }
}
