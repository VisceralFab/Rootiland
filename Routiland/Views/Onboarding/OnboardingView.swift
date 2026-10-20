import SwiftUI

// MARK: - Onboarding Flow
// Welcome → topic → activity → duration → frequency → time → summary → reminders → Leafy.
// The first habit is saved only when onboarding finishes, together with the "finished"
// flag, so quitting halfway through never leaves a duplicate habit behind.
private enum OnboardingPage: Int, CaseIterable {
    case welcome, category, activity, duration, frequency, time, summary, notifications, leafyIntro

    // The setup steps counted by the progress dots, from choosing a topic to the summary.
    static let setupSteps: [OnboardingPage] = [.category, .activity, .duration, .frequency, .time, .summary]
}

struct OnboardingView: View {
    @EnvironmentObject private var store: RootilandStore
    @State private var page: OnboardingPage
    // Which way the pages slide.
    @State private var movingForward = true

    // The habit being set up.
    @State private var category: HabitCategory = .movement
    @State private var selectedActivity = "Walk"
    @State private var minutes = 30
    @State private var frequency: HabitFrequency = .daily
    @State private var customDates: Set<DateComponents> = []
    @State private var reminderTime = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: .now) ?? .now
    // Set the first time the time page appears, after which the user's choice is kept.
    @State private var hasSuggestedTime = false

    @State private var showingDayPicker = false
    @State private var showCustomActivity = false
    @State private var customActivity = ""
    @State private var isRequestingPermission = false

    private static let maxActivityLength = 30

    init() {
        page = .welcome
    }

    // Lets the previews below open straight on a given page.
    fileprivate init(startingAt startPage: OnboardingPage) {
        page = startPage
    }

    var body: some View {
        VStack(spacing: 0) {
            // Every page after the welcome can go back, including the summary.
            if page != .welcome {
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

            pageContainer
                .id(page)
                .transition(pageTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The native bottom action remains tappable above the Home Indicator.
            if page != .notifications {
                VStack(spacing: 12) {
                    if OnboardingPage.setupSteps.contains(page) {
                        dots
                    }
                    RootilandPrimaryButton(title: buttonTitle) { advance() }
                        .disabled(!canAdvance)
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .background(RootilandDesign.canvas(darkMode: store.darkMode))
            }
        }
        .alert("Custom activity", isPresented: $showCustomActivity) {
            TextField("Activity name", text: $customActivity)
            Button("Cancel", role: .cancel) { customActivity = "" }
            Button("Save") {
                let value = customActivity.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { selectedActivity = value }
                customActivity = ""
            }
        } message: {
            Text("Give your habit a short, recognizable name (up to \(Self.maxActivityLength) characters).")
        }
        // Keeps custom names short enough for every card and row in the app.
        .onChange(of: customActivity) { _, value in
            if value.count > Self.maxActivityLength {
                customActivity = String(value.prefix(Self.maxActivityLength))
            }
        }
        .sheet(isPresented: $showingDayPicker) {
            HabitDaysSheet(dates: $customDates)
        }
    }

    // Pages fill the screen like before, but scroll whenever their content is taller, such as
    // with large text sizes or on smaller iPhones, so nothing hides behind the bottom button.
    private var pageContainer: some View {
        GeometryReader { proxy in
            ScrollView {
                pageContent
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
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

    private var pageTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity))
    }

    private var buttonTitle: String {
        switch page {
        case .welcome: "Get Started"
        case .summary: "Looks Good"
        case .leafyIntro: "Start My Journey"
        default: "Next"
        }
    }

    // "Specific days" needs at least one day picked before moving on.
    private var canAdvance: Bool {
        page != .frequency || frequency != .custom || !customDates.isEmpty
    }

    private var dots: some View {
        let steps = OnboardingPage.setupSteps
        let current = steps.firstIndex(of: page) ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(steps.count)")
    }

    // MARK: Pages

    private var welcomeContent: some View {
        VStack(spacing: 22) {
            Spacer()
            AccentHeading(firstLine: "Build habits", highlightedLine: "In Rootine.")
            Spacer()
            BundleResourceImage(name: "flower-mascot")
                .frame(width: 148, height: 148)
                .accessibilityLabel("Rootine flower mascot")
            Spacer()
            bodyText("Turn small actions into habits. Track your progress, stay focused, and keep moving forward.",
                     font: .system(.headline, design: .rounded))
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
                    Button { selectCategory(item) } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            // The topic's own color; selection is shown by the border.
                            Image(systemName: item.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(item.iconColor)
                                .frame(width: 44, height: 44)
                                .background(RootilandDesign.iconBackground, in: RoundedRectangle(cornerRadius: 12))
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
            bodyText("Choose a topic. You can explore more areas later.",
                     font: .system(.subheadline, design: .rounded).weight(.semibold))
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
    }

    private var activityContent: some View {
        // Topics are named by their short title everywhere in onboarding.
        choicePage(first: "Start with one small", second: "Habit", subtitle: category.shortTitle,
                   description: "Choose the activity you would like to do regularly.") {
            VStack(spacing: 18) {
                ForEach(category.suggestions) { suggestion in
                    RootilandOptionRow(title: suggestion.title, symbol: suggestion.symbol,
                                       selected: selectedActivity == suggestion.title) {
                        selectedActivity = suggestion.title
                    }
                }
                if !isSuggestion(selectedActivity) {
                    // The custom activity can be tapped to rename it; picking a suggestion replaces it.
                    RootilandOptionRow(title: selectedActivity, symbol: "pencil", selected: true) {
                        customActivity = selectedActivity
                        showCustomActivity = true
                    }
                    .accessibilityHint("Rename your custom activity")
                }
                Button {
                    customActivity = ""
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
        // The same hours-and-minutes wheel as the habit editor (and the Clock app's Timer).
        choicePage(first: "Make it fit your", second: "Routine", subtitle: selectedActivity,
                   description: "A pace you can keep is better than a perfect plan.") {
            VStack(spacing: 8) {
                Text(Habit.durationText(minutes))
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                DurationWheelPicker(minutes: $minutes)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Duration")
                    .accessibilityValue(Habit.durationText(minutes))
            }
        }
    }

    private var frequencyContent: some View {
        choicePage(first: "Make it fit your", second: "Calendar", subtitle: "How often?",
                   description: "Consistency is what transforms average into excellence.") {
            VStack(spacing: 14) {
                ForEach(HabitFrequency.allCases) { choice in
                    RootilandOptionRow(title: choice.title,
                                       symbol: choice == .custom ? "calendar.badge.plus" : "calendar",
                                       selected: frequency == choice) {
                        frequency = choice
                        // Open the calendar straight away the first time "Specific days" is picked.
                        if choice == .custom && customDates.isEmpty { showingDayPicker = true }
                    }
                }
                if frequency == .custom {
                    Button { showingDayPicker = true } label: {
                        Label(customDaysSummary, systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                    }
                    .accessibilityHint("Opens a calendar to choose the days")
                }
                // Says exactly when the habit repeats, including the day weekly and monthly use.
                Text(frequencyDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
    }

    private var timeContent: some View {
        VStack(spacing: 24) {
            AccentHeading(firstLine: "When should we", highlightedLine: "Remind you?")
            Text(selectedActivity)
                .font(.system(.headline, design: .rounded))
            Spacer()
            DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Habit reminder time")
            bodyText("Your reminder arrives at this time on each day of the habit.",
                     font: .footnote, style: .secondary)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var summaryContent: some View {
        VStack(spacing: 24) {
            AccentHeading(firstLine: "Awesome, that's a", highlightedLine: "Great habit!")
                .padding(.top, 24)
            Spacer()
            BundleResourceImage(name: "flower-happy")
                .frame(width: 90, height: 90)
                .accessibilityLabel("Happy Rootine flower mascot")
            // Everything that will be saved, including the topic and the reminder time.
            VStack(spacing: 12) {
                summaryItem(selectedActivity, symbol: activitySymbol)
                summaryItem(category.shortTitle, symbol: category.symbol)
                summaryItem(Habit.durationText(minutes), symbol: "timer")
                summaryItem(frequencySummary, symbol: "calendar")
                summaryItem("Reminder at \(TimeText.clock(reminderTime))", symbol: "bell")
            }
            .padding(.horizontal, 26)
            .accessibilityElement(children: .combine)
            bodyText("Go back to change anything.", font: .footnote, style: .secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var notificationContent: some View {
        VStack(spacing: 20) {
            AccentHeading(firstLine: "One last thing:", highlightedLine: "Reminders")
                .padding(.top, 24)
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Don't Miss Your Habit")
                    .font(.title2.weight(.bold))
                // Says what the reminders actually do, and where they can be turned off.
                bodyText("Get a gentle reminder at the time you picked for each habit. You can turn reminders off anytime in the Settings app.",
                         font: .subheadline, style: .secondary)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            // Follows light and dark mode like the rest of the app's cards.
            .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 28))
            Spacer()
            RootilandPrimaryButton(title: "Allow Notifications") {
                // Disabled while the permission prompt is up, so a second tap can't skip a page.
                isRequestingPermission = true
                Task {
                    _ = await store.enableNotifications()
                    isRequestingPermission = false
                    advance()
                }
            }
            .disabled(isRequestingPermission)
            Button("Skip For Now") { advance() }
                .font(.subheadline.weight(.medium))
                .padding(.vertical, 8)
                .disabled(isRequestingPermission)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }

    private var leafyIntroduction: some View {
        let days = RootilandStore.daysNeededForLevel
        return VStack(spacing: 18) {
            AccentHeading(firstLine: "Let me present you", highlightedLine: "Leafy")
                .padding(.top, 8)
            // The real island the user will grow, starting at level 1.
            IslandRealityView(modelName: "leafy_island", level: 1, height: 280)
            // Matches how Leafy actually grows: from fully completed days.
            bodyText("Leafy is your personal companion. Every day you complete all of your habits, its island grows: level 2 after \(days[1]) completed days, level 3 after \(days[2]), and on up to level \(days.count).",
                     font: .system(.headline, design: .rounded))
                .padding(.horizontal, 8)
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
    }

    // MARK: Building Blocks

    // Centered text that wraps naturally instead of using hard-coded line breaks.
    private func bodyText(_ text: String, font: Font, style: HierarchicalShapeStyle = .primary) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(style)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
            .fixedSize(horizontal: false, vertical: true)
    }

    // Summary cards are informational; unlike selectable onboarding rows,
    // they do not pretend to be buttons.
    private func summaryItem(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    // Reusable layout shared by the activity, duration and frequency pages.
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
            bodyText(description, font: .system(.subheadline, design: .rounded).weight(.semibold))
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 28)
    }

    // MARK: Habit Details

    private func isSuggestion(_ title: String) -> Bool {
        category.suggestions.contains { $0.title == title }
    }

    private var activitySymbol: String {
        category.suggestions.first { $0.title == selectedActivity }?.symbol ?? "pencil"
    }

    private var sortedCustomDates: [Date] {
        customDates.compactMap { Calendar.current.date(from: $0) }.sorted()
    }

    // "Choose days", "20 Oct, 22 Oct" or "6 days".
    private var customDaysSummary: String {
        let dates = sortedCustomDates
        switch dates.count {
        case 0: return "Choose days"
        case 1...3: return dates.map { $0.formatted(.dateTime.day().month(.abbreviated).locale(RootilandDesign.locale)) }
            .joined(separator: ", ")
        default: return "\(dates.count) days"
        }
    }

    // The habit is created today, so weekly and monthly habits repeat on today's weekday or date.
    private var frequencyDetail: String {
        switch frequency {
        case .daily:
            return "Repeats every day."
        case .weekly:
            return "Repeats every \(Date.now.formatted(.dateTime.weekday(.wide).locale(RootilandDesign.locale))), the weekday you start."
        case .monthly:
            let day = Calendar.current.component(.day, from: .now)
            return "Repeats on day \(day) of each month, the date you start."
                + (day > 28 ? " Months without that day are skipped." : "")
        case .custom:
            return customDates.isEmpty ? "Pick the days in the calendar." : "Happens only on the days you picked."
        }
    }

    private var frequencySummary: String {
        switch frequency {
        case .daily: return "Every day"
        case .weekly: return "Every \(Date.now.formatted(.dateTime.weekday(.wide).locale(RootilandDesign.locale)))"
        case .monthly: return "Day \(Calendar.current.component(.day, from: .now)) of each month"
        case .custom: return customDates.count == 1 ? "1 chosen day" : "\(customDates.count) chosen days"
        }
    }

    // A sensible first reminder for each topic; the user can change it on the time page.
    private func suggestedReminderTime(for category: HabitCategory) -> Date {
        let (hour, minute): (Int, Int) = switch category {
        case .movement: (7, 30)
        case .wellbeing: (21, 0)
        case .growth: (20, 0)
        case .study: (9, 0)
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    // MARK: Navigation

    private func selectCategory(_ item: HabitCategory) {
        // Only replace the activity if it's still the previous topic's suggestion,
        // so a custom name the user typed is never overwritten.
        if item != category && isSuggestion(selectedActivity) {
            selectedActivity = item.suggestions[0].title
        }
        category = item
    }

    private func previousPage() {
        guard let previous = OnboardingPage(rawValue: page.rawValue - 1) else { return }
        movingForward = false
        withAnimation(.smooth(duration: 0.3)) { page = previous }
    }

    private func advance() {
        if page == .leafyIntro {
            finishOnboarding()
            return
        }
        guard let next = OnboardingPage(rawValue: page.rawValue + 1) else { return }
        if next == .time && !hasSuggestedTime {
            reminderTime = suggestedReminderTime(for: category)
            hasSuggestedTime = true
        }
        movingForward = true
        withAnimation(.smooth(duration: 0.3)) { page = next }
    }

    // Saves the habit and marks onboarding finished in the same step, so onboarding can
    // never run twice for the same habit. Adding it also schedules its reminder if allowed.
    private func finishOnboarding() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        store.addHabit(Habit(category: category,
                             title: selectedActivity,
                             durationMinutes: minutes,
                             frequency: frequency,
                             reminderHour: components.hour ?? 8,
                             reminderMinute: components.minute ?? 0,
                             customDays: frequency == .custom ? sortedCustomDates.map(Habit.dayKey(for:)) : []))
        store.finishedOnboarding = true
    }
}

// 24-hour "07:30", matching the rest of the app.
private enum TimeText {
    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

#Preview("Onboarding") {
    OnboardingView().environmentObject(RootilandStore())
}

#Preview("Frequency") {
    OnboardingView(startingAt: .frequency).environmentObject(RootilandStore())
}

#Preview("Summary") {
    OnboardingView(startingAt: .summary).environmentObject(RootilandStore())
}

#Preview("Reminders") {
    OnboardingView(startingAt: .notifications).environmentObject(RootilandStore())
}

#Preview("Leafy") {
    OnboardingView(startingAt: .leafyIntro).environmentObject(RootilandStore())
}
