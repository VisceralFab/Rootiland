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
        case leafy
        case timeline
        // The prominent + in the tab bar. It never stays selected; it opens the New Habit sheet.
        case addHabit
    }

    @EnvironmentObject private var store: RootilandStore
    // The app opens on the Timeline.
    @State private var selection: AppTab = .timeline
    @State private var showingAddHabit = false
    // Counts how often each tab has been selected, to replay its icon animation.
    @State private var iconAnimationTriggers: [AppTab: Int] = [:]

    var body: some View {
        TabView(selection: $selection) {
            // MARK: Track
            // Shows today's habits and Leafy's growth. Topics opens from its top bar.
            SwiftUI.Tab(value: AppTab.track) {
                NavigationStack { TrackView() }
            } label: {
                tabLabel("Track", systemImage: "chart.bar.xaxis", tab: .track, effect: .bounceUp)
            }

            // MARK: Leafy
            // Displays the growing 3D island using RealityKit.
            SwiftUI.Tab(value: AppTab.leafy) {
                NavigationStack { LeafyView() }
            } label: {
                tabLabel("Leafy", systemImage: "leaf.fill", tab: .leafy, effect: .wiggle)
            }

            // MARK: Timeline
            // Shows the week and the day's agenda.
            SwiftUI.Tab(value: AppTab.timeline) {
                NavigationStack { HabitTimelineView() }
            } label: {
                tabLabel("Timeline", systemImage: "calendar.day.timeline.left", tab: .timeline, effect: .bounceUp)
            }

            // MARK: Add Habit
            // The prominent role gives this tab its own circle at the end of the tab bar.
            SwiftUI.Tab(value: AppTab.addHabit, role: .prominent) {
                Color.clear
            } label: {
                Label {
                    Text("Add Habit")
                } icon: {
                    // The tab bar redraws icons in its own colors, so the plus is pre-colored
                    // with the theme and marked "always original" to keep that color.
                    Image(uiImage: themedPlusImage)
                }
            }
        }
        .onChange(of: selection) { oldTab, newTab in
            if newTab == .addHabit {
                // Stay on the current tab and open the sheet instead of switching.
                selection = oldTab
                showingAddHabit = true
            } else {
                iconAnimationTriggers[newTab, default: 0] += 1
            }
        }
        .sheet(isPresented: $showingAddHabit) { HabitEditorView() }
    }

    // Color only the symbol; the tab keeps the system glass background.
    private var themedPlusImage: UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        return (UIImage(systemName: "plus", withConfiguration: configuration) ?? UIImage())
            .withTintColor(UIColor(store.accentTheme.color), renderingMode: .alwaysOriginal)
    }

    // MARK: - Animated Tab Icons
    // When a tab becomes selected its symbol plays a short animation, like the reference:
    // the leaf wiggles and the other icons bounce.
    private enum IconEffect {
        case bounceUp, wiggle
    }

    @ViewBuilder
    private func tabLabel(_ title: String, systemImage: String, tab: AppTab, effect: IconEffect) -> some View {
        let trigger = iconAnimationTriggers[tab, default: 0]
        Label {
            Text(title)
        } icon: {
            switch effect {
            case .bounceUp:
                Image(systemName: systemImage).symbolEffect(.bounce.up.byLayer, value: trigger)
            case .wiggle:
                Image(systemName: systemImage).symbolEffect(.wiggle.byLayer, value: trigger)
            }
        }
    }
}

// MARK: - Xcode Preview
// Opens the tab bar without having to complete onboarding.
#Preview {
    MainTabView().environmentObject(RootilandStore())
}
