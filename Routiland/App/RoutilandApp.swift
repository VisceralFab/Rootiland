import SwiftUI

// MARK: - Routiland App Entry Point
// Creates shared app data, applies the chosen accent color, and opens the root screen.
@main
struct RoutilandApp: App {
    @StateObject private var store = RoutilandStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "en"))
                .tint(store.accentTheme.color)
                // Force light or dark mode directly so the Settings toggle updates instantly.
                .preferredColorScheme(store.darkMode ? .dark : .light)
        }
    }
}
