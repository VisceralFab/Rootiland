import SwiftUI
import UIKit

// MARK: - Settings Tab
// This screen keeps the Apple-like layout but uses a custom panel
// so color changes and appearance changes feel immediate across the app.
struct SettingsView: View {
    @EnvironmentObject private var store: RoutilandStore
    @State private var presentedSheet: SettingsSheet?

    private enum SettingsSheet: String, Identifiable {
        case units, color
        var id: String { rawValue }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(get: { store.notificationsEnabled }, set: { shouldEnable in
            if shouldEnable {
                Task {
                    let allowed = await NotificationService.requestPermission()
                    store.notificationsEnabled = allowed
                    if allowed {
                        await NotificationService.scheduleAll(store.habits)
                    } else {
                        openSystemSettings()
                    }
                }
            } else {
                store.notificationsEnabled = false
                NotificationService.removeAll(for: store.habits)
            }
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    SettingsPanelRow(title: "Notification", systemImage: "bell") {
                        Toggle("", isOn: notificationBinding)
                            .labelsHidden()
                            .tint(store.accentTheme.color)
                    }

                    panelDivider

                    SettingsPanelRow(title: "Dark mode", systemImage: "moon") {
                        Toggle("", isOn: $store.darkMode)
                            .labelsHidden()
                            .tint(store.accentTheme.color)
                    }

                    panelDivider

                    SettingsPanelRow(title: "Language", systemImage: "globe") {
                        Button(action: openSystemSettings) {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    panelDivider

                    Button { presentedSheet = .units } label: {
                        SettingsPanelRow(title: "Units", systemImage: "ruler") {
                            HStack(spacing: 8) {
                                Text(store.measurementSystem.title)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    panelDivider

                    Button { presentedSheet = .color } label: {
                        SettingsPanelRow(title: "Primary Color", systemImage: "paintpalette") {
                            HStack(spacing: 8) {
                                Text(store.accentTheme.title)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(RoutilandDesign.separator(darkMode: store.darkMode), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(store.accentTheme.color)
                        Text("Routiland")
                            .font(.headline)
                        Spacer()
                    }

                    Text("App made by 4th Law Team.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(20)
        }
        .background(RoutilandDesign.canvas(darkMode: store.darkMode).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .units: MeasurementSystemSheet()
            case .color: PrimaryColorSheet()
            }
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(RoutilandDesign.separator(darkMode: store.darkMode))
            .frame(height: 1)
            .padding(.leading, 54)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// Both pickers share their presentation, spacing, background and Done control.
private struct SettingsSelectionSheet<Content: View>: View {
    @EnvironmentObject private var store: RoutilandStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    content()
                }
                .padding(24)
            }
            .background(RoutilandDesign.canvas(darkMode: store.darkMode))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct SettingsSelectionPreview: View {
    @EnvironmentObject private var store: RoutilandStore
    let symbol: String
    let title: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 56, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 112, height: 112)
            .background(store.accentTheme.color, in: Circle())
            .accessibilityLabel("\(title) preview")

        Text(title)
            .font(.title.bold())
            .foregroundStyle(store.accentTheme.color)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MeasurementSystemSheet: View {
    @EnvironmentObject private var store: RoutilandStore

    var body: some View {
        SettingsSelectionSheet(title: "Units") {
            SettingsSelectionPreview(symbol: "ruler", title: store.measurementSystem.title)

            VStack(spacing: 0) {
                ForEach(MeasurementSystem.allCases) { system in
                    Button {
                        withAnimation(.smooth) { store.measurementSystem = system }
                    } label: {
                        HStack {
                            Text(system.title).foregroundStyle(.primary)
                            Spacer()
                            if store.measurementSystem == system {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(store.accentTheme.color)
                            }
                        }
                        .padding(18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.measurementSystem == system ? [.isSelected] : [])

                    if system != MeasurementSystem.allCases.last {
                        Divider().padding(.horizontal, 18)
                    }
                }
            }
            .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct PrimaryColorSheet: View {
    @EnvironmentObject private var store: RoutilandStore

    var body: some View {
        SettingsSelectionSheet(title: "Primary Color") {
            SettingsSelectionPreview(symbol: "leaf.fill", title: "Rootiland")

            HStack(spacing: 36) {
                ForEach(AccentTheme.allCases) { theme in
                    Button {
                        withAnimation(.smooth) { store.accentTheme = theme }
                    } label: {
                        VStack(spacing: 10) {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 48, height: 48)
                                .padding(6)
                                .overlay {
                                    Circle()
                                        .strokeBorder(theme == store.accentTheme ? Color.primary : .clear, lineWidth: 3)
                                }
                            Text(theme.title)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.title)
                    .accessibilityAddTraits(theme == store.accentTheme ? [.isSelected] : [])
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Reusable Settings Row
// Keeps the settings panel organized for team members who read the code later.
private struct SettingsPanelRow<Accessory: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.primary)
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        SettingsView().environmentObject(RoutilandStore())
    }
}
