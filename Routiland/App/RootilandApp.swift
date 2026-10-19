import SwiftUI

// MARK: - Rootiland App Entry Point
// Creates shared app data, applies the chosen accent color, and opens the root screen.
@main
struct RootilandApp: App {
    @StateObject private var store = RootilandStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.locale, RootilandDesign.locale)
                .tint(store.accentTheme.color)
                // Force light or dark mode directly so the Settings toggle updates instantly.
                .preferredColorScheme(store.darkMode ? .dark : .light)
        }
        // Keep the Notification toggle in step with the permission in the Settings app.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await store.syncNotificationPermission() }
        }
    }
}
