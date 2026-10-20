import SwiftUI
import UIKit

// MARK: - Settings Tab
// This screen keeps the Apple-like layout but uses a custom panel
// so color changes and appearance changes feel immediate across the app.
struct SettingsView: View {
    @EnvironmentObject private var store: RootilandStore
    @State private var showingColorSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    // Opens this app's notification page in the iPhone's Settings app.
                    Button(action: openNotificationSettings) {
                        SettingsPanelRow(title: "Notification", systemImage: "bell") {
                            systemSettingsAccessory(store.notificationsEnabled ? "On" : "Off")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens notification settings in the Settings app")

                    panelDivider

                    Button { showingColorSheet = true } label: {
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
                .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(RootilandDesign.separator(darkMode: store.darkMode), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(store.accentTheme.color)
                        Text("Rootiland")
                            .font(.headline)
                        Spacer()
                    }

                    Text("App made by 4th Law Team.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(20)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingColorSheet) {
            PrimaryColorSheet()
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(RootilandDesign.separator(darkMode: store.darkMode))
            .frame(height: 1)
            .padding(.leading, 54)
    }

    // The current value plus an arrow-out icon, showing the row leaves the app.
    private func systemSettingsAccessory(_ value: String) -> some View {
        HStack(spacing: 8) {
            Text(value)
            Image(systemName: "arrow.up.forward.app")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }

    // iOS only lists the app under Notifications after permission has been asked for once,
    // so the first tap shows the permission prompt instead.
    private func openNotificationSettings() {
        Task {
            if await NotificationService.authorizationStatus() == .notDetermined {
                _ = await store.enableNotifications()
            } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        }
    }
}

// Presentation, spacing and Done control for the primary color picker.
private struct SettingsSelectionSheet<Content: View>: View {
    @EnvironmentObject private var store: RootilandStore
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
            .background(RootilandDesign.canvas(darkMode: store.darkMode))
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
    @EnvironmentObject private var store: RootilandStore
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
            .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct PrimaryColorSheet: View {
    @EnvironmentObject private var store: RootilandStore

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
            .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
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
        SettingsView().environmentObject(RootilandStore())
    }
}
