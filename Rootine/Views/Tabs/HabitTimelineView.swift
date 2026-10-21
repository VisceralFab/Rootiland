import SwiftUI

// MARK: - Timeline Tab
// A week overview places every habit at its reminder time. A bottom panel peeks at
// the next habit and can be dragged up into the selected day's agenda, where habits
// are checked off.
struct HabitTimelineView: View {
    @EnvironmentObject private var store: RootilandStore
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var panelExpanded = false
    @State private var headerHeight: CGFloat = 0
    @State private var showingDatePicker = false
    @State private var showingAddHabit = false

    private let collapsedPanelHeight: CGFloat = 104

    var body: some View {
        // The clock only drives the "now" markers, so a minute refresh is enough.
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddHabit) { HabitEditorView() }
    }

    private func content(now: Date) -> some View {
        let week = TimelineCalendar.week(containing: selectedDay).map { day in
            DaySchedule(day: day, occurrences: occurrences(on: day))
        }
        let selected = week.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDay) }
            ?? DaySchedule(day: selectedDay, occurrences: occurrences(on: selectedDay))

        return GeometryReader { geometry in
            let expandedHeight = max(collapsedPanelHeight, geometry.size.height - headerHeight)

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        header(now: now)
                        weekStrip(week, now: now)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 16)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

                    if store.habits.isEmpty {
                        ContentUnavailableView("No habits yet", systemImage: "calendar.day.timeline.left",
                                               description: Text("Add a habit to see it on your timeline."))
                            .padding(.bottom, collapsedPanelHeight)
                    } else {
                        WeekGrid(week: week, selectedDay: selectedDay, now: now, darkMode: store.darkMode,
                                 select: select, open: open)
                            .padding(.horizontal, 16)
                            .padding(.bottom, collapsedPanelHeight + 12)
                            .opacity(panelExpanded ? 0 : 1)
                            .allowsHitTesting(!panelExpanded)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                SlidingDayPanel(schedule: selected, now: now, expanded: $panelExpanded,
                                expandedHeight: expandedHeight, collapsedHeight: collapsedPanelHeight,
                                darkMode: store.darkMode, toggle: toggle,
                                addHabit: { showingAddHabit = true })
            }
        }
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        let month = selectedDay.formatted(.dateTime.month(.wide).locale(RootilandDesign.locale))
        let title = panelExpanded ? "\(selectedDay.formatted(.dateTime.day())) \(month)" : month

        return HStack(alignment: .firstTextBaseline) {
            Button { showingDatePicker = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(selectedDay.formatted(.dateTime.year())).foregroundStyle(Color.accentColor)
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
                .font(.title.bold())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose a date")
            .popover(isPresented: $showingDatePicker) {
                DatePicker("Go to date", selection: Binding(get: { selectedDay }, set: { date in
                    select(date)
                    showingDatePicker = false
                }), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(width: 320)
                .padding()
                .presentationCompactAdaptation(.popover)
            }

            Spacer()

            if !Calendar.current.isDate(selectedDay, inSameDayAs: now) {
                Button("Today") { select(now) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
            }
        }
    }

    // MARK: Week Strip

    private func weekStrip(_ week: [DaySchedule], now: Date) -> some View {
        HStack(spacing: 0) {
            // Lines the days up with the grid columns, which start after the hour labels.
            Color.clear.frame(width: WeekGrid.axisWidth, height: 0)
            ForEach(week) { schedule in
                let isSelected = Calendar.current.isDate(schedule.day, inSameDayAs: selectedDay)
                let isToday = Calendar.current.isDate(schedule.day, inSameDayAs: now)
                Button { select(schedule.day) } label: {
                    VStack(spacing: 4) {
                        Text(schedule.day.formatted(.dateTime.weekday(.abbreviated).locale(RootilandDesign.locale)))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(schedule.day.formatted(.dateTime.day()))
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                            .frame(width: 34, height: 34)
                            .background { if isSelected { Circle().fill(Color.accentColor) } }
                        habitDots(schedule)
                            .opacity(panelExpanded ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(schedule.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityValue("\(schedule.occurrences.count) habits")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        // Swipe sideways to move between weeks.
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                guard abs(value.translation.width) > max(40, abs(value.translation.height)) else { return }
                shiftWeek(by: value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    // Small overlapping dots in each habit's color, shown while the agenda is open.
    private func habitDots(_ schedule: DaySchedule) -> some View {
        HStack(spacing: -3) {
            ForEach(schedule.occurrences.prefix(4)) { occurrence in
                Circle()
                    .fill(occurrence.color)
                    .frame(width: 9, height: 9)
                    .overlay { Circle().strokeBorder(RootilandDesign.canvas(darkMode: store.darkMode), lineWidth: 1) }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func select(_ date: Date) {
        withAnimation(.smooth) { selectedDay = Calendar.current.startOfDay(for: date) }
    }

    private func open(_ date: Date) {
        select(date)
        setPanel(expanded: true)
    }

    private func setPanel(expanded: Bool) {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.88)) { panelExpanded = expanded }
    }

    private func shiftWeek(by weeks: Int) {
        guard let day = Calendar.current.date(byAdding: .day, value: weeks * 7, to: selectedDay) else { return }
        select(day)
    }

    private func toggle(_ occurrence: TimelineOccurrence) {
        withAnimation(.smooth) { store.toggleCompletion(occurrence.habit, on: occurrence.day) }
    }

    // MARK: Schedule

    private func occurrences(on day: Date) -> [TimelineOccurrence] {
        store.habits
            .filter { $0.isScheduled(on: day) }
            .map { TimelineOccurrence(habit: $0, day: day) }
            .sorted { ($0.startMinute, $0.habit.title) < ($1.startMinute, $1.habit.title) }
    }
}

// Keeping the drag state inside this view prevents every finger movement from
// rebuilding the week grid behind the panel.
private struct SlidingDayPanel: View {
    let schedule: DaySchedule
    let now: Date
    @Binding var expanded: Bool
    let expandedHeight: CGFloat
    let collapsedHeight: CGFloat
    let darkMode: Bool
    let toggle: (TimelineOccurrence) -> Void
    let addHabit: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var height: CGFloat {
        let base = expanded ? expandedHeight : collapsedHeight
        return min(max(base - dragOffset, collapsedHeight), expandedHeight)
    }

    private var progress: CGFloat {
        (height - collapsedHeight) / max(1, expandedHeight - collapsedHeight)
    }

    var body: some View {
        let agendaOpacity = min(max((progress - 0.08) / 0.3, 0), 1)

        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { setExpanded(!expanded) }
                .gesture(dragGesture)
                .accessibilityElement()
                .accessibilityLabel(expanded ? "Collapse day" : "Expand day")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { setExpanded(!expanded) }

            ZStack(alignment: .top) {
                peek
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .simultaneousGesture(dragGesture)
                    .opacity(1 - agendaOpacity)
                    .allowsHitTesting(!expanded)

                DayAgenda(schedule: schedule, now: now, darkMode: darkMode,
                          toggle: toggle, addHabit: addHabit)
                    .opacity(agendaOpacity)
                    .allowsHitTesting(expanded)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(RootilandDesign.cardBackground(darkMode: darkMode), in: RoundedRectangle(cornerRadius: 30))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.08), radius: 14, y: -2)
        .padding(.horizontal, 12 * (1 - progress))
        .padding(.bottom, 8 * (1 - progress))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in dragOffset = value.translation.height }
            .onEnded { value in
                let range = max(1, expandedHeight - collapsedHeight)
                let projectedHeight = (expanded ? expandedHeight : collapsedHeight)
                    - value.predictedEndTranslation.height
                let threshold: CGFloat = expanded ? 0.65 : 0.35
                setExpanded((projectedHeight - collapsedHeight) / range >= threshold)
            }
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.88)) {
            expanded = value
            dragOffset = 0
        }
    }

    // The collapsed card shows the habit that needs attention next.
    @ViewBuilder
    private var peek: some View {
        if let occurrence = schedule.focus(now: now) {
            HStack(spacing: 14) {
                HabitBadge(occurrence: occurrence, height: 52)
                    .onTapGesture { setExpanded(true) }
                VStack(alignment: .leading, spacing: 2) {
                    HabitTimeLabel(occurrence: occurrence)
                    HabitTitle(occurrence: occurrence)
                }
                .onTapGesture { setExpanded(true) }
                Spacer(minLength: 0)
                CompletionButton(occurrence: occurrence, toggle: toggle)
            }
            .padding(.horizontal, 18)
        } else {
            HStack {
                Text("No habits on this day")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Habit", systemImage: "plus", action: addHabit)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
        }
    }
}

// MARK: - Schedule Model

private struct TimelineOccurrence: Identifiable {
    let habit: Habit
    let day: Date

    var id: String { "\(habit.id.uuidString)-\(Habit.dayKey(for: day))" }
    var startMinute: Int { habit.reminderHour * 60 + habit.reminderMinute }
    var endMinute: Int { min(24 * 60, startMinute + habit.durationMinutes) }
    var start: Date {
        Calendar.current.date(bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: day) ?? day
    }
    var end: Date { start.addingTimeInterval(TimeInterval(habit.durationMinutes * 60)) }
    var isCompleted: Bool { habit.isCompleted(on: day) }
    var color: Color { habit.category.color }
    // Completed days grow Leafy, so only today's habits can be checked off.
    var canComplete: Bool { Calendar.current.isDateInToday(day) }
}

private struct DaySchedule: Identifiable {
    let day: Date
    let occurrences: [TimelineOccurrence]

    var id: String { Habit.dayKey(for: day) }

    // Today: the next unfinished habit that hasn't ended yet. Other days: the first unfinished one.
    func focus(now: Date) -> TimelineOccurrence? {
        let pending = occurrences.filter { !$0.isCompleted }
        if Calendar.current.isDate(day, inSameDayAs: now) {
            return pending.first { $0.end > now } ?? pending.first ?? occurrences.last
        }
        return pending.first ?? occurrences.first
    }
}

private enum TimelineCalendar {
    // Weeks run Monday to Sunday, matching the design.
    static func week(containing day: Date) -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let start = calendar.dateInterval(of: .weekOfYear, for: day)?.start else { return [day] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

private enum TimelineFormat {
    // 24-hour clock, e.g. "16:30". POSIX keeps the pattern exact on every device.
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // "16:30"
    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }

    // "16:00 – 16:30 (30 min)"
    static func range(_ occurrence: TimelineOccurrence) -> String {
        "\(clock(occurrence.start)) – \(clock(occurrence.end)) (\(Habit.durationText(occurrence.habit.durationMinutes)))"
    }

    // "4h 31m"
    static func duration(from start: Date, to end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        let hours = minutes / 60
        if hours == 0 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(hours)h" : "\(hours)h \(minutes % 60)m"
    }

    // Hour-axis label: "06", "14", "24".
    static func hourLabel(_ hour: Int) -> String { String(format: "%02d", hour) }
}

// MARK: - Time Scale
// Maps a time of day to a vertical position. Stretches of time without habits are
// compressed and every habit keeps at least `minimumGap` points from the next one,
// so a whole week fits on one screen without icons overlapping.
private struct TimeScale {
    private(set) var points: [(minute: Double, y: CGFloat)] = []
    let totalHeight: CGFloat
    let startHour: Int
    let endHour: Int

    init(eventMinutes: [Int], height: CGFloat, minimumGap: CGFloat = 42, inset: CGFloat = 22) {
        let events = Set(eventMinutes).sorted()
        // Always show at least a waking day (06–22), so a week with only one or two habits
        // doesn't stretch them across the whole screen; earlier or later habits widen it.
        let start = min((events.first ?? 6 * 60) / 60 * 60, 6 * 60)
        let end = max(min(24 * 60, ((events.last ?? 21 * 60) / 60 + 1) * 60), 22 * 60)
        let keys = Set([start, end] + events).sorted()
        let eventSet = Set(events)
        let available = max(height - inset * 2, 1)

        func length(_ pointsPerMinute: Double, _ index: Int) -> CGFloat {
            let linear = CGFloat(Double(keys[index + 1] - keys[index]) * pointsPerMinute)
            let betweenHabits = eventSet.contains(keys[index]) && eventSet.contains(keys[index + 1])
            return betweenHabits ? max(minimumGap, linear) : linear
        }
        func total(_ pointsPerMinute: Double) -> CGFloat {
            (0..<(keys.count - 1)).reduce(0) { $0 + length(pointsPerMinute, $1) }
        }

        // Find the scale that makes the timeline fill the available height. If the
        // minimum gaps alone are taller, the grid scrolls instead.
        var low = 0.0
        var high = Double(available) / Double(end - start)
        for _ in 0..<30 {
            let middle = (low + high) / 2
            if total(middle) > available { high = middle } else { low = middle }
        }

        var y = inset
        var points = [(minute: Double(keys[0]), y: y)]
        for index in 0..<(keys.count - 1) {
            y += length(low, index)
            points.append((minute: Double(keys[index + 1]), y: y))
        }
        self.points = points
        totalHeight = y + inset
        startHour = start / 60
        endHour = end / 60
    }

    func y(_ minute: Double) -> CGFloat {
        guard let first = points.first, let last = points.last else { return 0 }
        if minute <= first.minute { return first.y }
        if minute >= last.minute { return last.y }
        guard let index = points.firstIndex(where: { $0.minute >= minute }), index > 0 else { return first.y }
        let a = points[index - 1]
        let b = points[index]
        return a.y + CGFloat((minute - a.minute) / (b.minute - a.minute)) * (b.y - a.y)
    }
}

// MARK: - Week Grid

private struct WeekGrid: View {
    static let axisWidth: CGFloat = 30
    private let iconSize: CGFloat = 38

    let week: [DaySchedule]
    let selectedDay: Date
    let now: Date
    let darkMode: Bool
    let select: (Date) -> Void
    let open: (Date) -> Void

    var body: some View {
        GeometryReader { geometry in
            let scale = TimeScale(eventMinutes: week.flatMap { $0.occurrences.map(\.startMinute) },
                                  height: geometry.size.height)
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    hourAxis(scale)
                    ForEach(week) { schedule in
                        dayColumn(schedule, scale: scale)
                    }
                }
                .frame(height: scale.totalHeight)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func hourAxis(_ scale: TimeScale) -> some View {
        // Skip labels that would sit on top of each other in compressed stretches.
        var lastY = -CGFloat.infinity
        var hours: [(hour: Int, y: CGFloat)] = []
        for hour in scale.startHour...scale.endHour {
            let y = scale.y(Double(hour * 60))
            if y - lastY >= 14 {
                hours.append((hour, y))
                lastY = y
            }
        }

        return ZStack(alignment: .topLeading) {
            ForEach(hours, id: \.hour) { item in
                Text(TimelineFormat.hourLabel(item.hour))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                .frame(width: Self.axisWidth, alignment: .leading)
                .offset(y: item.y - 6)
            }
        }
        .frame(width: Self.axisWidth, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func dayColumn(_ schedule: DaySchedule, scale: TimeScale) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(schedule.day, inSameDayAs: selectedDay)
        let ys = schedule.occurrences.map { scale.y(Double($0.startMinute)) }
        let firstY = ys.first ?? 0
        let lastY = ys.last ?? 0
        let slots = Dictionary(grouping: schedule.occurrences, by: \.startMinute)
            .sorted { $0.key < $1.key }

        return ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { select(schedule.day) }

            if ys.count > 1 {
                Capsule()
                    .fill(RootilandDesign.separator(darkMode: darkMode))
                    .frame(width: 3, height: lastY - firstY)
                    .offset(y: firstY)
                    .allowsHitTesting(false)

                if isSelected {
                    progressLine(schedule, ys: ys)
                }
            } else {
                // With one habit or none there's nothing to join, so a dotted line still marks
                // out the day from the first hour to the last.
                let top = scale.points.first?.y ?? 0
                let bottom = scale.points.last?.y ?? scale.totalHeight
                VerticalLine()
                    .stroke(Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                    .frame(width: 3, height: max(0, bottom - top))
                    .offset(y: top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            ForEach(Array(slots.enumerated()), id: \.element.key) { index, slot in
                let top = scale.y(Double(slot.key)) - iconSize / 2
                let height = slotHeight(slot.value, scale: scale,
                                        nextStart: index + 1 < slots.count ? slots[index + 1].key : nil)
                Button { open(schedule.day) } label: {
                    GridIcon(occurrences: slot.value, highlighted: isSelected, width: iconSize, height: height)
                }
                .buttonStyle(.plain)
                .offset(y: top)
                .accessibilityLabel(slot.value.map(\.habit.title).joined(separator: ", "))
                .accessibilityValue("\(TimelineFormat.clock(slot.value[0].start)), \(schedule.day.formatted(.dateTime.weekday(.wide)))")
                .accessibilityHint("Show this day's habits")
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // Habits with a duration stretch into a capsule, stopping short of the next habit.
    private func slotHeight(_ occurrences: [TimelineOccurrence], scale: TimeScale, nextStart: Int?) -> CGFloat {
        guard let longest = occurrences.max(by: { $0.endMinute < $1.endMinute }) else { return iconSize }
        let startY = scale.y(Double(longest.startMinute))
        var height = scale.y(Double(longest.endMinute)) - startY + iconSize
        if let nextStart {
            height = min(height, scale.y(Double(nextStart)) - startY - 4)
        }
        return max(iconSize, height)
    }

    // The selected day's line fills in each habit's color up to the current time.
    private func progressLine(_ schedule: DaySchedule, ys: [CGFloat]) -> some View {
        let calendar = Calendar.current
        let firstY = ys.first ?? 0
        let lastY = ys.last ?? 0
        let elapsedY: CGFloat
        if calendar.isDate(schedule.day, inSameDayAs: now) {
            let minutes = Double(calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now))
            let starts = schedule.occurrences.map { Double($0.startMinute) }
            // Interpolate between the habits' own positions so the fill matches the icons.
            if let next = starts.firstIndex(where: { $0 > minutes }) {
                if next == 0 {
                    elapsedY = firstY
                } else {
                    let fraction = (minutes - starts[next - 1]) / max(1, starts[next] - starts[next - 1])
                    elapsedY = ys[next - 1] + CGFloat(fraction) * (ys[next] - ys[next - 1])
                }
            } else {
                elapsedY = lastY
            }
        } else {
            elapsedY = schedule.day < now ? lastY : firstY
        }

        return ZStack(alignment: .top) {
            // Each stretch takes the sky's colors for its hours, whatever the accent theme.
            ForEach(0..<(ys.count - 1), id: \.self) { index in
                LinearGradient(stops: DaylightPalette.stops(fromMinute: Double(schedule.occurrences[index].startMinute),
                                                            toMinute: Double(schedule.occurrences[index + 1].startMinute)),
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: 3, height: ys[index + 1] - ys[index])
                    .offset(y: ys[index])
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .mask(alignment: .top) {
            Rectangle().frame(height: max(0, elapsedY))
        }
        .allowsHitTesting(false)
    }
}

private struct GridIcon: View {
    let occurrences: [TimelineOccurrence]
    let highlighted: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let occurrence = occurrences[0]
        ZStack {
            // Like Structured: the selected day shows solid circles in the topic color with a
            // white symbol; other days show solid grey circles with the colorful symbol. Both
            // are opaque so the day's line passes behind them instead of through them.
            Capsule()
                .fill(highlighted ? occurrence.habit.category.iconColor : Color(uiColor: .systemGray5))
            if highlighted {
                Capsule().strokeBorder(.background, lineWidth: 2)
            }
            Image(systemName: occurrence.habit.category.symbol)
                .symbolVariant(.fill)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(highlighted ? Color.white : occurrence.habit.category.iconColor)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .bottomTrailing) {
            if occurrences.count > 1 {
                Text("\(occurrences.count)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(3)
                    .background(Color.primary, in: Circle())
                    .offset(x: 5, y: 3)
            } else if occurrence.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(occurrence.habit.category.onColor, occurrence.color)
                    .offset(x: 4, y: 3)
            }
        }
    }
}

// MARK: - Day Agenda

private struct DayAgenda: View {
    let schedule: DaySchedule
    let now: Date
    let darkMode: Bool
    let toggle: (TimelineOccurrence) -> Void
    let addHabit: () -> Void

    private enum Entry: Identifiable {
        case habit(TimelineOccurrence)
        case gap(id: String, gap: Gap)

        var id: String {
            switch self {
            case .habit(let occurrence): occurrence.id
            case .gap(let id, _): id
            }
        }
    }

    // The space between two habits (or before the first / after the last one today).
    private struct Gap {
        let from: TimelineOccurrence?
        let to: TimelineOccurrence?
        let start: Date
        let end: Date?
        let index: Int
    }

    var body: some View {
        if schedule.occurrences.isEmpty {
            ContentUnavailableView {
                Label("No habits on this day", systemImage: "calendar")
            } actions: {
                addButton
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        switch entry {
                        case .habit(let occurrence):
                            habitRow(occurrence)
                        case .gap(_, let gap):
                            gapRow(gap)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var entries: [Entry] {
        let items = schedule.occurrences
        let isToday = Calendar.current.isDate(schedule.day, inSameDayAs: now)
        var result: [Entry] = []

        if isToday, let first = items.first, now < first.start {
            result.append(.gap(id: "before", gap: Gap(from: nil, to: first, start: now, end: first.start, index: 0)))
        }
        for (index, occurrence) in items.enumerated() {
            result.append(.habit(occurrence))
            if index + 1 < items.count {
                let next = items[index + 1]
                result.append(.gap(id: "gap-\(occurrence.id)",
                                   gap: Gap(from: occurrence, to: next, start: occurrence.end, end: next.start, index: index)))
            }
        }
        if isToday, let last = items.last, now >= last.end {
            result.append(.gap(id: "after", gap: Gap(from: last, to: nil, start: last.end, end: nil, index: items.count)))
        }
        return result
    }

    // MARK: Rows

    private func habitRow(_ occurrence: TimelineOccurrence) -> some View {
        let badgeHeight = 52 + min(CGFloat(occurrence.habit.durationMinutes), 120) * 0.5

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing) {
                Text(TimelineFormat.clock(occurrence.start))
                Spacer(minLength: 0)
                Text(TimelineFormat.clock(occurrence.end))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .frame(width: 40, height: badgeHeight, alignment: .trailing)
            .accessibilityHidden(true)

            HabitBadge(occurrence: occurrence, height: badgeHeight)

            VStack(alignment: .leading, spacing: 2) {
                HabitTimeLabel(occurrence: occurrence)
                HabitTitle(occurrence: occurrence)
            }
            .padding(.top, 6)

            Spacer(minLength: 0)

            CompletionButton(occurrence: occurrence, toggle: toggle)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func gapRow(_ gap: Gap) -> some View {
        let isToday = Calendar.current.isDate(schedule.day, inSameDayAs: now)
        let containsNow = isToday && gap.start <= now && (gap.end.map { now < $0 } ?? true)
        let isPast = gap.end.map { $0 <= now } ?? false
        let hasRoom = (gap.end.map { $0.timeIntervalSince(gap.start) } ?? 1) > 0

        if !hasRoom && !containsNow {
            // Back-to-back habits: just continue the line.
            connector(gap)
                .frame(height: 16)
                // Lines up under the badges, past the 40pt time column and 12pt spacing.
                .padding(.leading, 52)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: 12) {
                Text(containsNow ? TimelineFormat.clock(now) : "")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
                    .accessibilityHidden(true)

                connector(gap)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    gapMessage(gap, containsNow: containsNow, isPast: isPast)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if containsNow {
                        addButton
                    }
                }
                .padding(.vertical, 22)

                Spacer(minLength: 0)
            }
            // Sizes the row to its message so the dashed line spans exactly that height.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func gapMessage(_ gap: Gap, containsNow: Bool, isPast: Bool) -> some View {
        if containsNow, let end = gap.end {
            Label {
                Text("\(Text(TimelineFormat.duration(from: now, to: end)).foregroundStyle(Color.accentColor).bold()) free; habits on the horizon.")
            } icon: {
                Image(systemName: "timer")
            }
        } else if containsNow {
            Label("Free for the rest of the day.", systemImage: "moon.stars")
        } else if isPast {
            Label(gap.index.isMultiple(of: 2) ? "Time well utilized!" : "A well-deserved break.", systemImage: "zzz")
        } else if let end = gap.end {
            Label("\(TimelineFormat.duration(from: gap.start, to: end)) free", systemImage: "hourglass")
        }
    }

    // Dashed line between habits. The time that has already passed takes the sky's colors,
    // from sunrise gold to night indigo, whatever the accent theme; the rest stays grey.
    private func connector(_ gap: Gap) -> some View {
        let calendar = Calendar.current
        let start = DaylightPalette.minute(of: gap.start)
        let nowMinute = DaylightPalette.minute(of: now)
        let end = gap.end.map(DaylightPalette.minute(of:)) ?? max(start, nowMinute)

        // How much of this stretch is behind us, from 0 to 1.
        let elapsed: Double
        if calendar.isDate(schedule.day, inSameDayAs: now) {
            elapsed = end > start ? min(max((nowMinute - start) / (end - start), 0), 1) : (nowMinute >= start ? 1 : 0)
        } else {
            elapsed = schedule.day < now ? 1 : 0
        }

        let upcoming = Color.secondary.opacity(0.35)
        var stops: [Gradient.Stop] = []
        if elapsed > 0 {
            stops = DaylightPalette.stops(fromMinute: start, toMinute: start + (end - start) * elapsed)
                .map { Gradient.Stop(color: $0.color, location: $0.location * elapsed) }
        }
        if elapsed < 1 {
            stops += [Gradient.Stop(color: upcoming, location: elapsed), Gradient.Stop(color: upcoming, location: 1)]
        }

        return VerticalLine()
            .stroke(LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 5]))
            .frame(width: 52)
            .accessibilityHidden(true)
    }

    private var addButton: some View {
        Button("Add Habit", systemImage: "plus.circle.fill", action: addHabit)
            .font(.subheadline.weight(.medium))
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
    }
}

// MARK: - Shared Agenda Pieces

private struct HabitBadge: View {
    let occurrence: TimelineOccurrence
    let height: CGFloat

    var body: some View {
        Image(systemName: occurrence.habit.category.symbol)
            .symbolVariant(.fill)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(occurrence.habit.category.iconColor)
            .frame(width: 52, height: height)
            .background(RootilandDesign.iconBackground, in: Capsule())
            .accessibilityHidden(true)
    }
}

private struct HabitTimeLabel: View {
    let occurrence: TimelineOccurrence

    var body: some View {
        HStack(spacing: 4) {
            Text(TimelineFormat.range(occurrence))
            // Daily, weekly and monthly habits repeat; habits on specific days don't.
            if occurrence.habit.frequency.repeats {
                Image(systemName: "repeat")
                    .font(.caption2.weight(.semibold))
                    .accessibilityLabel(occurrence.habit.frequency.title)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct HabitTitle: View {
    let occurrence: TimelineOccurrence

    var body: some View {
        Text(occurrence.habit.title)
            .font(.headline)
            .strikethrough(occurrence.isCompleted)
            .foregroundStyle(occurrence.isCompleted ? .secondary : .primary)
            .lineLimit(2)
    }
}

private struct CompletionButton: View {
    let occurrence: TimelineOccurrence
    let toggle: (TimelineOccurrence) -> Void
    // Bumped each time the habit is checked off, to play the confetti.
    @State private var confettiTrigger = 0

    var body: some View {
        Button {
            if !occurrence.isCompleted { confettiTrigger += 1 }
            toggle(occurrence)
        } label: {
            Image(systemName: occurrence.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 26, weight: .regular))
                // Checked: a dark check on the topic color. Unchecked: the deepened topic color, so pale topics still show.
                .foregroundStyle(occurrence.isCompleted ? occurrence.habit.category.onColor : occurrence.habit.category.deepColor,
                                 occurrence.isCompleted ? occurrence.color : occurrence.habit.category.deepColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay {
            ConfettiBurst(trigger: confettiTrigger, colors: [occurrence.color, .yellow, .orange, .pink, .mint, .purple])
        }
        .disabled(!occurrence.canComplete)
        .opacity(occurrence.canComplete || occurrence.isCompleted ? 1 : 0.4)
        .sensoryFeedback(.success, trigger: confettiTrigger)
        .accessibilityLabel(occurrence.isCompleted ? "Mark \(occurrence.habit.title) incomplete"
                                                   : "Complete \(occurrence.habit.title)")
        .accessibilityHint(occurrence.canComplete ? "" : "Only today's habits can be checked off")
    }
}

private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

#Preview {
    NavigationStack { HabitTimelineView().environmentObject(RootilandStore()) }
}

#Preview("With habits") {
    NavigationStack { HabitTimelineView().environmentObject(timelinePreviewStore()) }
}

// The expanded panel on its own, as it looks after dragging the card up.
// A week with a single weekly habit, so most days show the dotted empty-day line.
#Preview("Sparse week") {
    let store = RootilandStore(defaults: UserDefaults(suiteName: "TimelineSparsePreview") ?? .standard)
    if store.habits.isEmpty {
        store.addHabit(Habit(category: .growth, title: "Read", durationMinutes: 30, frequency: .weekly,
                             reminderHour: 9, reminderMinute: 0))
    }
    return NavigationStack { HabitTimelineView().environmentObject(store) }
}

#Preview("Day agenda") {
    let store = timelinePreviewStore()
    let today = Calendar.current.startOfDay(for: .now)
    DayAgenda(schedule: DaySchedule(day: today,
                                    occurrences: store.habits.map { TimelineOccurrence(habit: $0, day: today) }),
              now: .now, darkMode: false, toggle: { _ in }, addHabit: {})
}

// Sample habits in throwaway storage, so the preview never touches real app data.
@MainActor
private func timelinePreviewStore() -> RootilandStore {
    let store = RootilandStore(defaults: UserDefaults(suiteName: "TimelinePreview") ?? .standard)
    if store.habits.isEmpty {
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        store.addHabit(Habit(category: .growth, title: "Read", durationMinutes: 15, frequency: .daily,
                             reminderHour: 7, reminderMinute: 0, createdAt: lastWeek))
        store.addHabit(Habit(category: .wellbeing, title: "Meditate", durationMinutes: 15, frequency: .daily,
                             reminderHour: 14, reminderMinute: 30, createdAt: lastWeek))
        store.addHabit(Habit(category: .movement, title: "Workout", durationMinutes: 45, frequency: .daily,
                             reminderHour: 16, reminderMinute: 0, createdAt: lastWeek))
        store.addHabit(Habit(category: .study, title: "Plan", durationMinutes: 30, frequency: .daily,
                             reminderHour: 21, reminderMinute: 30, createdAt: lastWeek))
    }
    return store
}
