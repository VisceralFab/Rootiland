import SwiftUI

// MARK: - Onboarding Flow
// The screen order mirrors the Sketch exports:
// Momentum app icon → Onboard 2 → 3 → 4 → 5 → 6 → Final → Notify → Leafy present.
private enum OnboardingPage: Int, CaseIterable {
    case welcome, category, activity, duration, frequency, time, summary, notifications, leafyIntro
}

struct OnboardingView: View {
    @EnvironmentObject private var store: RoutilandStore
    @State private var page: OnboardingPage = .welcome
    @State private var category: HabitCategory = .movement
    @State private var selectedActivity = "Walk"
    @State private var minutes = 30
    @State private var frequency: HabitFrequency = .daily
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var showCustomActivity = false
    @State private var customActivity = ""

    var body: some View {
        VStack(spacing: 0) {
            if page != .welcome && page != .summary && page != .notifications && page != .leafyIntro {
                HStack {
                    Button(action: previousPage) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Back")
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
            }

            Group {
                switch page {
                case .welcome: welcomeContent
                case .category: categoryContent
                case .activity: activityContent
                case .duration: durationContent
                case .frequency: frequencyContent
                case .time: timeContent
                case .summary: summaryContent
                case .notifications: notificationContent
                case .leafyIntro: leafyIntroduction
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(RoutilandDesign.canvas(darkMode: store.darkMode).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The native bottom action remains tappable above the Home Indicator.
            if page != .notifications {
                VStack(spacing: 12) {
                    if [.welcome, .category, .activity, .duration, .frequency, .time].contains(page) {
                        dots
                    }
                    RoutilandPrimaryButton(title: buttonTitle) { advance() }
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .background(RoutilandDesign.canvas(darkMode: store.darkMode))
            }
        }
        .animation(.smooth(duration: 0.25), value: page)
        .alert("New activity", isPresented: $showCustomActivity) {
            TextField("Activity name", text: $customActivity)
            Button("Cancel", role: .cancel) { customActivity = "" }
            Button("Add") {
                let value = customActivity.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { selectedActivity = value }
                customActivity = "" }
        } message: {
            Text("Give your new habit a short, recognizable name.")
        }
    }

    private var buttonTitle: String {
        switch page {
        case .welcome: "Get Started"
        case .summary: "Finish Setup"
        case .leafyIntro: "Continue"
        default: "Next"
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index == min(page.rawValue, 5) ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("Step \(min(page.rawValue + 1, 6)) of 6")
    }

    private var welcomeContent: some View {
        VStack(spacing: 22) {
            Spacer()
            AccentHeading(firstLine: "Build habits", highlightedLine: "In Routiland.")
            Spacer()
            BundleResourceImage(name: "flower-mascot")
                .frame(width: 148, height: 148)
                .accessibilityLabel("Routiland flower mascot")
            Spacer()
            Text("Turn small actions into habits.\nTrack your progress, stay focused,\nand keep moving forward.")
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
    }

    private var categoryContent: some View {
        VStack(spacing: 24) {
            AccentHeading(firstLine: "What do you want to", highlightedLine: "Improve?")
                .padding(.top, 4)
            Spacer(minLength: 20)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 22) {
                ForEach(HabitCategory.allCases) { item in
                    Button {
                        category = item
                        selectedActivity = item.suggestions[0].title
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: item.symbol)
                                .font(.title2)
                                // Selection should highlight only the border, not the icon itself.
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text(item.shortTitle)
                                .font(.system(.headline, design: .rounded))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 142)
                        .background {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(.background)
                                .shadow(color: .black.opacity(0.09), radius: 0, y: 4)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(category == item ? Color.accentColor : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == item ? .isSelected : [])
                }
            }
            Spacer(minLength: 15)
            Text("Choose a category.\nYou can explore more areas later.")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
    }

    private var activityContent: some View {
        choicePage(first: "Start with one small", second: "Habit", subtitle: category.title,
                   description: "Choose the activity you would\nlike to do regularly.") {
            VStack(spacing: 18) {
                ForEach(category.suggestions) { suggestion in
                    RoutilandOptionRow(title: suggestion.title, symbol: suggestion.symbol,
                                       selected: selectedActivity == suggestion.title) {
                        selectedActivity = suggestion.title
                    }
                }
                if !category.suggestions.contains(where: { $0.title == selectedActivity }) {
                    RoutilandOptionRow(title: selectedActivity, symbol: "star", selected: true, action: {})
                }
                Button {
                    showCustomActivity = true
                } label: {
                    Label("Custom activity", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.top, 8)
            }
        }
    }

    private var durationContent: some View {
        choicePage(first: "Make it fit your", second: "Routine", subtitle: selectedActivity,
                   description: "A pace you can keep is better\nthan a perfect plan.") {
            VStack(spacing: 18) {
                ForEach([30, 45, 60], id: \.self) { choice in
                    RoutilandOptionRow(title: choice == 60 ? "1 hour" : "\(choice) minutes",
                                       symbol: "timer", selected: minutes == choice) {
                        minutes = choice
                    }
                }
            }
        }
    }

    private var frequencyContent: some View {
        choicePage(first: "Make it fit your", second: "Calendar", subtitle: "How many times?",
                   description: "Consistency is what transforms\naverage into excellence.") {
            VStack(spacing: 18) {
                ForEach(HabitFrequency.allCases) { choice in
                    RoutilandOptionRow(title: choice.title, symbol: "calendar", selected: frequency == choice) {
                        frequency = choice
                    }
                }
            }
        }
    }

    private var timeContent: some View {
        VStack(spacing: 24) {
            AccentHeading(firstLine: "Make it fit your", highlightedLine: "Daily")
            Text("Precisely when?")
                .font(.system(.headline, design: .rounded))
            Spacer()
            DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Habit reminder time")
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var summaryContent: some View {
        VStack(spacing: 28) {
            AccentHeading(firstLine: "Awesome, that's a", highlightedLine: "Great habit!")
                .padding(.top, 40)
            Spacer()
            BundleResourceImage(name: "flower-happy")
                .frame(width: 110, height: 110)
                .accessibilityLabel("Happy Routiland flower mascot")
            VStack(spacing: 17) {
                summaryItem(selectedActivity, symbol: category.suggestions.first(where: { $0.title == selectedActivity })?.symbol ?? "star")
                summaryItem("\(minutes) minutes", symbol: "timer")
                summaryItem(frequency.title, symbol: "calendar")
            }
            .padding(.horizontal, 26)
            .accessibilityElement(children: .combine)
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var notificationContent: some View {
        VStack(spacing: 20) {
            AccentHeading(firstLine: "Awesome, that is a", highlightedLine: "Great habit!")
                .padding(.top, 40)
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)
                Text("Don't Miss Your Habit")
                    .font(.title2.weight(.bold))
                Text("Stay on track with customizable\nalerts about your habits.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
            .background(.black, in: RoundedRectangle(cornerRadius: 28))
            .environment(\.colorScheme, .dark)
            Spacer()
            RoutilandPrimaryButton(title: "Allow Notifications") {
                Task {
                    store.notificationsEnabled = await NotificationService.requestPermission()
                    if store.notificationsEnabled { await NotificationService.scheduleAll(store.habits) }
                    advance()
                }
            }
            Button("Skip For Now") { advance() }
                .font(.subheadline.weight(.medium))
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }

    private var leafyIntroduction: some View {
        VStack(spacing: 20) {
            Spacer()
            AccentHeading(firstLine: "Let me present you", highlightedLine: "Leafy")
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 98))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Spacer()
            Text("Leafy is your personal companion.\nEvery completed task gives your island\nexperience and helps it grow over time.")
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer(minLength: 25)
        }
        .padding(.horizontal, 28)
    }

    // Summary cards are informational; unlike selectable onboarding rows,
    // they do not pretend to be buttons.
    private func summaryItem(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    // Reusable layout shared by screens 3, 4, and 5.
    private func choicePage<Content: View>(first: String, second: String, subtitle: String,
                                           description: String, @ViewBuilder choices: () -> Content) -> some View {
        VStack(spacing: 22) {
            AccentHeading(firstLine: first, highlightedLine: second)
            Text(subtitle)
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
            Spacer(minLength: 15)
            choices()
            Spacer(minLength: 15)
            Text(description)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 28)
    }

    private func previousPage() {
        guard page.rawValue > 0 else { return }
        page = OnboardingPage(rawValue: page.rawValue - 1) ?? .welcome
    }

    private func advance() {
        // Finishing setup creates the first real habit once, rather than sample data.
        if page == .summary {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            store.addHabit(Habit(category: category,
                                 title: selectedActivity,
                                 durationMinutes: minutes,
                                 frequency: frequency,
                                 reminderHour: components.hour ?? 8,
                                 reminderMinute: components.minute ?? 0))
        }
        if page == .leafyIntro {
            store.finishedOnboarding = true
        } else {
            page = OnboardingPage(rawValue: page.rawValue + 1) ?? .welcome
        }
    }
}

#Preview("Onboarding") {
    OnboardingView().environmentObject(RoutilandStore())
}
