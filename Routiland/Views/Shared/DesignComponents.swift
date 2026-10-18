import SwiftUI
import UIKit

// MARK: - Design Tokens
// Shared colors and reusable controls keep all screens visually consistent.
enum RoutilandDesign {
    // The app uses a true black canvas in dark mode to feel closer
    // to Apple's Clock app. In light mode we use a soft grouped background.
    static func canvas(darkMode: Bool) -> Color {
        darkMode ? .black : Color(uiColor: .systemGroupedBackground)
    }

    // Cards use system backgrounds so controls still feel native.
    static func cardBackground(darkMode: Bool) -> Color {
        darkMode ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }

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
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

struct RoutilandPrimaryButton: View {
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

struct RoutilandOptionRow: View {
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
    RoutilandOptionRow(title: "30 minutes", symbol: "timer", selected: true, action: {})
        .padding()
}

// A system glass action placed inside the bottom safe area, above the tab bar.
struct AddHabitAction: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Add habit")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
