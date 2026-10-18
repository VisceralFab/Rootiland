import SwiftUI

// MARK: - Timeline Tab
// Time labels appear on the left, with one column for each day of the month.
struct HabitTimelineView: View {
    @EnvironmentObject private var store: RoutilandStore
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedGroup: TimelineOccurrenceGroup?
    @State private var horizontalOffset: CGFloat = 0

    private let slotHeight: CGFloat = 72
    private let columnWidth: CGFloat = 52
    private let timeColumnWidth: CGFloat = 66
    private let totalSlots = 24
    private let timelineInset: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineHeader(displayedMonth: displayedMonth, changeMonth: changeMonth)
                .padding(.bottom, 24)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                timelineBody(at: context.date)
            }
        }
        .padding(.horizontal, 18)
        .background(RoutilandDesign.canvas(darkMode: store.darkMode).ignoresSafeArea())
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedGroup) { group in
            TimelineOccurrenceSheet(group: group)
        }
    }

    private func timelineBody(at now: Date) -> some View {
        let followsClock = Calendar.current.isDate(displayedMonth, equalTo: now, toGranularity: .month)
        let startMinutes = followsClock ? minutesSinceMidnight(at: now) : 0
        let visibleHeight = gridHeight - position(for: startMinutes) + timelineInset * 2

        return VStack(spacing: 0) {
            // Keep the day headings visible and aligned while either axis scrolls.
            HStack(spacing: 8) {
                Color.clear.frame(width: timeColumnWidth, height: 48)
                GeometryReader { _ in
                    dayHeadings(at: now)
                        .offset(x: -horizontalOffset)
                }
                .frame(height: 48)
                .clipped()
            }

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    timeAxis(at: now, startMinutes: startMinutes, followsClock: followsClock)
                        .frame(width: timeColumnWidth, height: visibleHeight, alignment: .topLeading)

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            timelineGrid(at: now, startMinutes: startMinutes, followsClock: followsClock)
                                .frame(width: CGFloat(monthDates.count) * columnWidth, height: visibleHeight, alignment: .topLeading)
                        }
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentOffset.x + geometry.contentInsets.leading
                        } action: { _, offset in
                            horizontalOffset = offset
                        }
                        .task(id: displayedMonth) {
                            let target = followsClock ? Calendar.current.startOfDay(for: now) : displayedMonth
                            proxy.scrollTo(target, anchor: .leading)
                        }
                    }
                }
            }
            .id(displayedMonth)
        }
    }

    private func dayHeadings(at now: Date) -> some View {
        HStack(spacing: 0) {
            ForEach(monthDates, id: \.self) { date in
                let isToday = Calendar.current.isDate(date, inSameDayAs: now)
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "en"))))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(date.formatted(.dateTime.day()))
                        .font(.subheadline.weight(isToday ? .bold : .semibold))
                        .foregroundStyle(isToday ? store.accentTheme.color : .primary)
                }
                .frame(width: columnWidth, height: 48)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func timeAxis(at now: Date, startMinutes: Double, followsClock: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(timeSlots, id: \.self) { minutes in
                let distance = position(for: Double(minutes) - startMinutes)
                if Double(minutes) >= startMinutes && (!followsClock || distance > 24) {
                    Text(timeLabel(for: minutes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .position(x: timeColumnWidth / 2, y: distance + timelineInset)
                }
            }

            if followsClock {
                Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(store.accentTheme.color, in: Capsule())
                    .position(x: timeColumnWidth / 2, y: timelineInset)
                    .accessibilityLabel("Current time")
                    .accessibilityValue(now.formatted(date: .omitted, time: .shortened))
            }
        }
    }

    private func timelineGrid(at now: Date, startMinutes: Double, followsClock: Bool) -> some View {
        let visibleHeight = gridHeight - position(for: startMinutes) + timelineInset * 2

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(monthDates, id: \.self) { date in
                    Rectangle()
                        .fill(RoutilandDesign.separator(darkMode: store.darkMode).opacity(0.5))
                        .frame(width: 1)
                        .frame(width: columnWidth, height: visibleHeight, alignment: .leading)
                        .id(date)
                }
            }

            // Only whole hours have a horizontal guide; the live clock uses the selected accent.
            ForEach(timeSlots, id: \.self) { minutes in
                if Double(minutes) >= startMinutes {
                    Rectangle()
                        .fill(RoutilandDesign.separator(darkMode: store.darkMode))
                        .frame(height: 1)
                        .offset(y: position(for: Double(minutes) - startMinutes) + timelineInset)
                        .allowsHitTesting(false)
                }
            }

            ForEach(occurrenceGroups) { group in
                if Double(group.minutes) >= startMinutes,
                   let dayIndex = monthDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: group.date) }) {
                    TimelineStackButton(group: group) {
                        selectedGroup = group
                    }
                    .position(
                        x: CGFloat(dayIndex) * columnWidth + columnWidth / 2,
                        y: position(for: Double(group.minutes) - startMinutes) + timelineInset
                    )
                }
            }

            if followsClock {
                // Draw last so the current time remains the main visual reference.
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(store.accentTheme.color)
                        .frame(height: 2)
                        .offset(y: timelineInset - 1)
                    if let todayIndex = monthDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: now) }) {
                        Circle()
                            .fill(store.accentTheme.color)
                            .frame(width: 10, height: 10)
                            .position(x: CGFloat(todayIndex) * columnWidth + columnWidth / 2, y: timelineInset)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    // Wall-clock components also keep the marker correct on daylight-saving days.
    private func minutesSinceMidnight(at date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            + Double(components.second ?? 0) / 60
    }

    private func position(for minutes: Double) -> CGFloat {
        CGFloat(minutes / 60) * slotHeight
    }

    private var monthDates: [Date] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        return range.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: displayedMonth) }
    }

    private var timeSlots: [Int] { Array(stride(from: 0, to: 24 * 60, by: 60)) }
    private var gridHeight: CGFloat { CGFloat(totalSlots) * slotHeight }

    private var occurrences: [TimelineOccurrence] {
        monthDates.flatMap { date in
            store.habits.compactMap { habit in
                guard isHabitScheduled(habit, on: date) else { return nil }
                return TimelineOccurrence(habit: habit, date: date)
            }
        }
    }

    private func isHabitScheduled(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        let scheduledDay = calendar.startOfDay(for: date)
        let creationDay = calendar.startOfDay(for: habit.createdAt)
        switch habit.frequency {
        case .daily:
            return scheduledDay >= creationDay
        case .weekly:
            return calendar.component(.weekday, from: scheduledDay) == calendar.component(.weekday, from: creationDay)
                && scheduledDay >= creationDay
        case .monthly:
            return calendar.component(.day, from: scheduledDay) == calendar.component(.day, from: creationDay)
                && scheduledDay >= creationDay
        }
    }

    private func timeLabel(for minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private var occurrenceGroups: [TimelineOccurrenceGroup] {
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            "\(Habit.dayKey(for: occurrence.date))-\(occurrence.habit.reminderHour)-\(occurrence.habit.reminderMinute)"
        }
        return grouped.values.compactMap { items in
            guard let first = items.first else { return nil }
            return TimelineOccurrenceGroup(
                date: first.date,
                minutes: first.habit.reminderHour * 60 + first.habit.reminderMinute,
                occurrences: items.sorted { $0.habit.id.uuidString < $1.habit.id.uuidString }
            )
        }.sorted { $0.id < $1.id }
    }

    private func changeMonth(_ offset: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth),
           let firstDay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: next)) {
            withAnimation(.smooth) { displayedMonth = firstDay }
        }
    }
}

private struct TimelineHeader: View {
    let displayedMonth: Date
    let changeMonth: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(displayedMonth.formatted(.dateTime.month(.wide).locale(Locale(identifier: "en"))))
            Text(displayedMonth.formatted(.dateTime.year()))
                .foregroundStyle(Color.accentColor)
                .padding(.leading, 2)
            Spacer()
            HStack(spacing: 8) {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").font(.headline) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Previous month")
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right").font(.headline) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Next month")
            }
        }
        .font(.largeTitle.bold())
    }
}

private struct TimelineOccurrence: Identifiable {
    let habit: Habit
    let date: Date
    var id: String { "\(habit.id.uuidString)-\(Habit.dayKey(for: date))" }
}

private struct TimelineOccurrenceGroup: Identifiable {
    let date: Date
    let minutes: Int
    let occurrences: [TimelineOccurrence]

    var id: String { "\(Habit.dayKey(for: date))-\(minutes)" }
}

// One hit target opens every habit in this time slot, including the covered icons.
private struct TimelineStackButton: View {
    let group: TimelineOccurrenceGroup
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                ForEach(Array(group.occurrences.prefix(3).enumerated()), id: \.element.id) { index, occurrence in
                    let layers = min(group.occurrences.count, 3)
                    let depth = layers - index - 1
                    let spread = CGFloat(layers - 1) * 2
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                        Circle()
                            .strokeBorder(.background, lineWidth: 2)
                        Image(systemName: occurrence.habit.category.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 32, height: 32)
                    .offset(x: CGFloat(depth) * 4 - spread, y: spread - CGFloat(depth) * 4)
                    .zIndex(Double(index))
                }
                if group.occurrences.count > 1 {
                    Text("\(group.occurrences.count)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .padding(3)
                        .background(Color.primary, in: Circle())
                        .offset(x: 14, y: 14)
                        .zIndex(4)
                } else if let occurrence = group.occurrences.first,
                          occurrence.habit.isCompleted(on: group.date) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 12, y: 12)
                        .zIndex(4)
                }
            }
            .frame(width: 48, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.occurrences.map(\.habit.title).joined(separator: ", "))
        .accessibilityValue("\(group.occurrences.count) habits at \(String(format: "%02d:%02d", group.minutes / 60, group.minutes % 60))")
        .accessibilityHint("Show habit details")
    }
}

private struct TimelineOccurrenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: TimelineOccurrenceGroup

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(group.occurrences) { occurrence in
                        HabitRow(habit: occurrence.habit, completionDate: occurrence.date, allowsDeletion: false)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year().locale(Locale(identifier: "en"))))
                        Label(String(format: "%02d:%02d", group.minutes / 60, group.minutes % 60), systemImage: "clock")
                    }
                    .textCase(nil)
                } footer: {
                    Text("Complete your habits in Track to help Leafy grow.")
                }
            }
            .navigationTitle(group.occurrences.count == 1 ? "Habit details" : "Scheduled habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack { HabitTimelineView().environmentObject(RoutilandStore()) }
}
