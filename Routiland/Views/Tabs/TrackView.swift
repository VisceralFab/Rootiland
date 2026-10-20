import SwiftUI

// MARK: - Track Tab
// A focused checklist for today's habits. New habits are added from the + in the tab bar.
struct TrackView: View {
    @EnvironmentObject private var store: RootilandStore
    @State private var showingTopics = false

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { context in
            trackContent(at: context.date)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationBarTitleDisplayMode(.inline)
        // Topics used to be its own tab; it now lives here so the tab bar has room for the +.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingTopics = true } label: {
                    Label("Topics", systemImage: "square.grid.2x2")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $showingTopics) {
            NavigationStack {
                TopicsView(initialCategory: store.habits.first?.category ?? .movement)
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func trackContent(at now: Date) -> some View {
        // Read through `now` so the list switches over at midnight.
        let todaysHabits = store.habits.filter { $0.isScheduled(on: now) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Track")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 10) { store.enableLeafyCheats() }
                    .sensoryFeedback(.success, trigger: store.isLeafyCheatMode)
                    .accessibilityAddTraits(.isHeader)

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
                    HabitListCard(habits: todaysHabits, allowsCompletion: true, completionDate: now)
                }
            }
            .padding(20)
        }
    }

    private func completionPercentage(of todaysHabits: [Habit]) -> Int {
        guard !todaysHabits.isEmpty else { return 0 }
        return Int(Double(store.completedToday) / Double(todaysHabits.count) * 100)
    }
}

#Preview {
    NavigationStack { TrackView().environmentObject(RootilandStore()) }
}
