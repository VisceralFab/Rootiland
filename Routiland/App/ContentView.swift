import SwiftUI

// MARK: - Main App Content
// The app starts here. Show onboarding on the first launch;
// after onboarding, show the five-tab main interface.
struct ContentView: View {
    @EnvironmentObject private var store: RoutilandStore

    var body: some View {
        Group {
            if store.finishedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(RoutilandStore())
}
