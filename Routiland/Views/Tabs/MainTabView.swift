import SwiftUI

// MARK: - Native Tab Navigation
// Apple's TabView creates the real system tab bar, including Liquid Glass.
// Each tab has its own NavigationStack, so navigation is independent.
struct MainTabView: View {

    // MARK: - Selected Tab
    // This enum stores WHICH tab is selected. It must not be named "Tab"
    // because SwiftUI already has a native control called Tab.
    private enum AppTab: Hashable {
        case track
        case topics
        case leafy
        case timeline
        case settings
    }

    @State private var selection: AppTab = .track

    var body: some View {
        TabView(selection: $selection) {
            // MARK: Track
            // Shows daily habits and the completion calendar.
            SwiftUI.Tab("Track", systemImage: "chart.bar.xaxis", value: AppTab.track) {
                NavigationStack { TrackView() }
            }

            // MARK: Topics
            // Lets the user organize habits by category.
            SwiftUI.Tab("Topics", systemImage: "list.bullet", value: AppTab.topics) {
                NavigationStack { TopicsView() }
            }

            // MARK: Leafy
            // Displays the growing 3D island using RealityKit.
            SwiftUI.Tab("Leafy", systemImage: "leaf.fill", value: AppTab.leafy) {
                NavigationStack { LeafyView() }
            }

            // MARK: Timeline
            // Shows when habits were completed in the past.
            SwiftUI.Tab("Timeline", systemImage: "calendar.day.timeline.left", value: AppTab.timeline) {
                NavigationStack { HabitTimelineView() }
            }

            // MARK: Settings
            // Manages notifications, appearance and the accent color.
            SwiftUI.Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
    }
}

// MARK: - Xcode Preview
// Opens the tab bar without having to complete onboarding.
#Preview {
    MainTabView().environmentObject(RoutilandStore())
}
