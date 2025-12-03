import SwiftUI
import FirebaseCore

@main
struct MrFunnyJokesApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
