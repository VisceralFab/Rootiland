import SwiftUI
import UIKit

// MARK: - Design Tokens
// Shared colors and reusable controls keep all screens visually consistent.
enum RootilandDesign {
    // English with a 24-hour clock (British English uses 24h). Applied to the whole app,
    // so every time picker and formatted time shows 00:00–23:59.
    static let locale = Locale(identifier: "en_GB")

    // The app uses a true black canvas in dark mode to feel closer
    // to Apple's Clock app. In light mode we use a soft grouped background.
    static func canvas(darkMode: Bool) -> Color {
        darkMode ? .black : Color(uiColor: .systemGroupedBackground)
    }

    // Cards use system backgrounds so controls still feel native.
    static func cardBackground(darkMode: Bool) -> Color {
        darkMode ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }

    // The neutral background behind topic icons; the icon itself carries the topic color.
    static let iconBackground = Color(uiColor: .tertiarySystemFill)

    static func separator(darkMode: Bool) -> Color {
        darkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }
}

struct AccentHeading: View {
    let firstLine: String
    let highlightedLine: String

    var body: some View {
        VStack(spacing: 1) {
            Text(firstLine).foregroundStyle(.primary)
            Text(highlightedLine).foregroundStyle(Color.accentColor)
        }
        // A text style rather than a fixed size, so headings grow with the user's text size.
        .font(.system(.title2, design: .rounded).weight(.bold))
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

struct RootilandPrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        // Native glassProminent uses the selected system tint on iOS 27.
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}

struct RootilandOptionRow: View {
    let title: String
    let symbol: String
    let selected: Bool
    var showsSelectionMark: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 32)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if selected && showsSelectionMark {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 64)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 0, y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Bundle Resource Image
// The design team can replace the mascot PNGs without touching SwiftUI layout code.
struct BundleResourceImage: View {
    let name: String
    let `extension`: String
    let subdirectory: String?
    var contentMode: ContentMode = .fit

    init(name: String, extension: String = "png", subdirectory: String? = "Models", contentMode: ContentMode = .fit) {
        self.name = name
        self.extension = `extension`
        self.subdirectory = subdirectory
        self.contentMode = contentMode
    }

    var body: some View {
        if let image = loadImage() {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage() -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: `extension`, subdirectory: subdirectory) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

#Preview("Option") {
    RootilandOptionRow(title: "30 minutes", symbol: "timer", selected: true, action: {})
        .padding()
}

// MARK: - Duration Wheel
// The hours-and-minutes wheel from the Clock app's Timer. SwiftUI has no countdown
// picker, so this wraps UIKit's UIDatePicker in `.countDownTimer` mode.
struct DurationWheelPicker: UIViewRepresentable {
    @Binding var minutes: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.minuteInterval = 1
        picker.locale = RootilandDesign.locale
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        // UIKit skips the first change event unless the duration is set after the
        // picker is on screen, so set it on the next main-actor turn.
        let seconds = TimeInterval(max(1, minutes) * 60)
        Task { @MainActor in picker.countDownDuration = seconds }
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.minutes = $minutes
        let seconds = TimeInterval(max(1, minutes) * 60)
        if picker.countDownDuration != seconds {
            picker.countDownDuration = seconds
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(minutes: $minutes) }

    final class Coordinator: NSObject {
        var minutes: Binding<Int>

        init(minutes: Binding<Int>) { self.minutes = minutes }

        // The wheel can't go below one minute, matching the Clock app.
        @objc func valueChanged(_ picker: UIDatePicker) {
            minutes.wrappedValue = max(1, Int(picker.countDownDuration / 60))
        }
    }
}

// MARK: - Daylight Palette
// Colors the day's timeline line like the sky: sunrise gold in the morning, warming to
// orange and sunset coral, then darkening through dusk plum to night indigo. It is the
// same for every accent theme.
enum DaylightPalette {
    private static let stops: [(minute: Double, red: Double, green: Double, blue: Double)] = [
        (5 * 60, 1.00, 0.82, 0.32),   // Sunrise gold
        (10 * 60, 1.00, 0.66, 0.24),  // Morning orange
        (14 * 60, 0.97, 0.50, 0.29),  // Afternoon amber
        (18 * 60, 0.86, 0.33, 0.39),  // Sunset coral
        (20 * 60, 0.53, 0.29, 0.54),  // Dusk plum
        (23 * 60, 0.22, 0.24, 0.48)   // Night indigo
    ]

    // The sky color at a minute of the day (0–1440). Before sunrise the line still
    // starts gold, so every day begins with the sun.
    static func color(atMinute minute: Double) -> Color {
        guard let first = stops.first, let last = stops.last else { return .orange }
        if minute <= first.minute { return Color(red: first.red, green: first.green, blue: first.blue) }
        if minute >= last.minute { return Color(red: last.red, green: last.green, blue: last.blue) }
        guard let index = stops.firstIndex(where: { $0.minute >= minute }), index > 0 else {
            return Color(red: first.red, green: first.green, blue: first.blue)
        }
        let a = stops[index - 1]
        let b = stops[index]
        let t = (minute - a.minute) / (b.minute - a.minute)
        return Color(red: a.red + (b.red - a.red) * t,
                     green: a.green + (b.green - a.green) * t,
                     blue: a.blue + (b.blue - a.blue) * t)
    }

    // Gradient stops spanning a stretch of the day, sampled so long stretches show
    // every color they pass through.
    static func stops(fromMinute start: Double, toMinute end: Double, samples: Int = 6) -> [Gradient.Stop] {
        guard end > start else { return [Gradient.Stop(color: color(atMinute: start), location: 0)] }
        return (0...samples).map { step in
            let fraction = Double(step) / Double(samples)
            return Gradient.Stop(color: color(atMinute: start + (end - start) * fraction), location: fraction)
        }
    }

    static func minute(of date: Date) -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }
}

// MARK: - Confetti Burst
// A small ring of confetti that pops out of a checkbox when a habit is completed.
// Increment `trigger` to play it once.
struct ConfettiBurst: View {
    let trigger: Int
    // How far the pieces travel beyond the checkbox, in points.
    var spread: CGFloat = 22
    var colors: [Color] = [.yellow, .orange, .pink, .mint, .purple, .blue]
    private let pieceCount = 12

    var body: some View {
        // Copied out because the animator's content closure isn't main-actor isolated.
        let count = pieceCount
        let colors = colors
        let spread = spread

        Color.clear
            .frame(width: 1, height: 1)
            // At rest the progress is 0, which draws nothing.
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, progress in
                ZStack {
                    content
                    ForEach(0..<count, id: \.self) { index in
                        Self.piece(index, count: count, color: colors[index % colors.count],
                                   spread: spread, progress: progress)
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(1.0, duration: 0.65, timingCurve: .easeOut)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // Each piece flies outward along its own angle, spinning and fading as it goes.
    private nonisolated static func piece(_ index: Int, count: Int, color: Color,
                                          spread: CGFloat, progress: Double) -> some View {
        let angle = Double(index) / Double(count) * 2 * .pi
        let distance = 12 + spread * progress
        return RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 4, height: index.isMultiple(of: 2) ? 8 : 4)
            .rotationEffect(.radians(angle + progress * 3))
            .scaleEffect(1 - progress * 0.4)
            .offset(x: cos(angle) * distance, y: sin(angle) * distance)
            .opacity(progress == 0 ? 0 : 1 - progress)
    }
}
