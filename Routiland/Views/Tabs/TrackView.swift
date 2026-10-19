import SwiftUI

// MARK: - Track Navigation
// Every screen that can be pushed onto Track's navigation stack.
enum TrackRoute: Hashable {
    case topics
    case topic(HabitCategory)
}

// MARK: - Track Tab
// A focused checklist for today's habits. New habits are added from the + in the tab bar.
struct TrackView: View {
    @EnvironmentObject private var store: RootilandStore

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { context in
            trackContent(at: context.date)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle("Track")
        // Topics used to be its own tab; it now lives here so the tab bar has room for the +.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: TrackRoute.topics) {
                    Label("Topics", systemImage: "square.grid.2x2")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        // All of Track's destinations are registered once, here at the root of its stack.
        // Mixing view-based links with destinations declared inside pushed screens made
        // SwiftUI push the same screen again and again.
        .navigationDestination(for: TrackRoute.self) { route in
            switch route {
            case .topics: TopicsView()
            case .topic(let category): TopicDetailView(category: category)
            }
        }
    }

    private func trackContent(at now: Date) -> some View {
        // Read through `now` so the list switches over at midnight.
        let todaysHabits = store.habits.filter { $0.isScheduled(on: now) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's habits").font(.title3.bold())
                        Text("\(store.completedToday) of \(todaysHabits.count) completed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !todaysHabits.isEmpty {
                        Text("\(completionPercentage(of: todaysHabits))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(store.accentTheme.color)
                    }
                }
                if store.habits.isEmpty {
                    ContentUnavailableView("Start a habit", systemImage: "checklist", description: Text("Add your first habit to begin tracking progress."))
                } else if todaysHabits.isEmpty {
                    ContentUnavailableView("Nothing due today", systemImage: "sun.max",
                                           description: Text("Your weekly, monthly and specific-day habits will show up here on their days."))
                } else {
                    VStack(spacing: 6) {
                        ForEach(todaysHabits) { habit in
                            HabitRow(habit: habit, allowsCompletion: true)
                                // Opaque so the row covers its swipe actions while sliding.
                                .background(RootilandDesign.cardBackground(darkMode: store.darkMode))
                                // Keeps the sliding text inside the row instead of past the card's edge.
                                .clipped()
                            if habit.id != todaysHabits.last?.id { Divider() }
                        }
                    }
                    .padding(15)
                    .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(20)
        }
        // Enables the habit rows' Edit and Delete swipe actions outside a List.
        .swipeActionsContainer()
    }

    private func completionPercentage(of todaysHabits: [Habit]) -> Int {
        guard !todaysHabits.isEmpty else { return 0 }
        return Int(Double(store.completedToday) / Double(todaysHabits.count) * 100)
    }
}

#Preview {
    NavigationStack { TrackView().environmentObject(RootilandStore()) }
}
