import SwiftUI

// MARK: - Topics
// Four topic cards reproduce the structure of "Homepage topics.svg".
// Opened from Track. Each card pushes a `TrackRoute.topic` value; Track's navigation
// stack registers where those values go, so destinations are declared in one place.
struct TopicsView: View {
    @EnvironmentObject private var store: RootilandStore
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(HabitCategory.allCases) { category in
                    NavigationLink(value: TrackRoute.topic(category)) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: category.symbol)
                                    .font(.title2)
                                    .foregroundStyle(store.accentTheme.color)
                                Spacer()
                                Text("\(store.habits.filter { $0.category == category }.count)")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(category.shortTitle)
                                .font(.system(.headline, design: .rounded))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(RootilandDesign.cardBackground(darkMode: store.darkMode))
                                .shadow(color: .black.opacity(0.08), radius: 0, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle("Topics")
    }
}

// MARK: - Topic Detail
// The topic's habits as a stack of cards, like Apple Wallet. Only each card's top edge
// shows; tapping a card brings it forward with its details and tucks the rest into a
// small pile underneath. Habits are checked off in Track and Timeline, not here.
// New habits are added from the + in the tab bar.
struct TopicDetailView: View {
    @EnvironmentObject private var store: RootilandStore
    let category: HabitCategory
    @State private var selectedHabitID: UUID?
    @State private var editingHabit: Habit?
    @State private var habitToDelete: Habit?

    // Card geometry: the full card, how much of each card shows in the stack,
    // and how much of each card shows in the pile below an opened card.
    private let cardHeight: CGFloat = 210
    private let stackedPeek: CGFloat = 64
    private let pilePeek: CGFloat = 12

    var body: some View {
        let habits = store.habits.filter { $0.category == category }

        Group {
            if habits.isEmpty {
                ContentUnavailableView("No habits yet", systemImage: category.symbol,
                                       description: Text("Add a habit to this topic with the + button."))
            } else {
                ScrollView {
                    cardStack(habits)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
            }
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle(category.shortTitle)
        .sheet(item: $editingHabit) { habit in HabitEditorView(habit: habit) }
        .confirmationDialog("Delete this habit?", isPresented: Binding(
            get: { habitToDelete != nil },
            set: { if !$0 { habitToDelete = nil } }
        ), titleVisibility: .visible, presenting: habitToDelete) { habit in
            Button("Delete \(habit.title)", role: .destructive) {
                withAnimation(.smooth) {
                    if selectedHabitID == habit.id { selectedHabitID = nil }
                    store.deleteHabit(habit)
                }
            }
        } message: { _ in
            Text("Its reminders and check-in history will be removed.")
        }
    }

    private func cardStack(_ habits: [Habit]) -> some View {
        let selectedIndex = habits.firstIndex { $0.id == selectedHabitID }
        let height: CGFloat = selectedIndex == nil
            ? CGFloat(habits.count - 1) * stackedPeek + cardHeight
            : cardHeight + 28 + CGFloat(habits.count - 1) * pilePeek + 40

        return ZStack(alignment: .top) {
            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                let isSelected = habit.id == selectedHabitID
                HabitWalletCard(habit: habit, shade: index,
                                isExpanded: selectedIndex == nil ? index == habits.count - 1 : isSelected,
                                edit: { editingHabit = habit }, delete: { habitToDelete = habit })
                    .frame(height: cardHeight)
                    .scaleEffect(scale(for: index, selectedIndex: selectedIndex), anchor: .top)
                    .offset(y: offset(for: index, selectedIndex: selectedIndex))
                    .zIndex(isSelected ? Double(habits.count) : Double(index))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            selectedHabitID = isSelected ? nil : habit.id
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(isSelected ? "Return the card to the stack" : "Show this habit's card")
            }
        }
        .frame(height: height, alignment: .top)
    }

    // Stacked: each card sits a peek below the previous one. With a card opened, it moves
    // to the top and the others gather in a tight pile below it.
    private func offset(for index: Int, selectedIndex: Int?) -> CGFloat {
        guard let selectedIndex else { return CGFloat(index) * stackedPeek }
        if index == selectedIndex { return 0 }
        let pilePosition = index < selectedIndex ? index : index - 1
        return cardHeight + 28 + CGFloat(pilePosition) * pilePeek
    }

    private func scale(for index: Int, selectedIndex: Int?) -> CGFloat {
        guard let selectedIndex, index != selectedIndex else { return 1 }
        return 0.94
    }
}

// MARK: - Wallet Card
// One habit as a colored card in its topic's color: title and icon along the top edge
// (the part visible in the stack) and its routine below.
private struct HabitWalletCard: View {
    let habit: Habit
    // The card's position in the stack, used to vary its shade like the cards in Wallet.
    let shade: Int
    let isExpanded: Bool
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: habit.category.symbol)
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.22), in: Circle())
                Text(habit.title)
                    .font(.title3.bold())
                    .lineLimit(1)
                Spacer(minLength: 8)
                Menu {
                    Button("Edit", systemImage: "pencil", action: edit)
                    Button("Delete", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.22), in: Circle())
                }
                .accessibilityLabel("Options for \(habit.title)")
            }
            .frame(height: 64)

            Spacer(minLength: 0)

            // The routine, laid out like the fields on a pass.
            HStack(alignment: .bottom) {
                cardField("REMINDER", String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute))
                Spacer()
                cardField("DURATION", Habit.durationText(habit.durationMinutes))
                Spacer()
                cardField("REPEATS", habit.frequency == .custom
                          ? (habit.customDays.count == 1 ? "1 day" : "\(habit.customDays.count) days")
                          : habit.frequency.title)
            }
            .opacity(isExpanded ? 1 : 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [cardColor, cardColor.mix(with: .black, by: 0.25)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.18), radius: 6, y: -2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(habit.title), reminder at \(String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute)), \(Habit.durationText(habit.durationMinutes)), \(habit.frequency.title)")
    }

    // Alternates lighter and darker versions of the topic color down the stack.
    private var cardColor: Color {
        let steps: [Double] = [0, 0.14, -0.12, 0.26]
        let step = steps[shade % steps.count]
        return step >= 0 ? habit.category.color.mix(with: .white, by: step)
                         : habit.category.color.mix(with: .black, by: -step)
    }

    private func cardField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .opacity(0.75)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// Opened through Track so the topic cards have their destinations registered.
#Preview {
    NavigationStack { TrackView() }
        .environmentObject(RootilandStore())
}

// The Wallet-style stack with sample habits, in throwaway storage.
#Preview("Topic cards") {
    NavigationStack { TopicDetailView(category: .movement) }
        .environmentObject(topicCardsPreviewStore())
}

@MainActor
private func topicCardsPreviewStore() -> RootilandStore {
    let store = RootilandStore(defaults: UserDefaults(suiteName: "TopicCardsPreview") ?? .standard)
    if store.habits.isEmpty {
        for (title, hour, minutes, frequency) in [("Walk", 7, 30, HabitFrequency.daily), ("Stretch", 12, 15, .daily),
                                                  ("Workout", 18, 60, .weekly), ("Swim", 9, 45, .monthly)] {
            store.addHabit(Habit(category: .movement, title: title, durationMinutes: minutes,
                                 frequency: frequency, reminderHour: hour, reminderMinute: 0))
        }
    }
    return store
}
