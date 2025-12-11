import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingTimePicker = false

    var body: some View {
        NavigationStack {
            List {
                notificationSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        Section {
            // Main toggle
            Toggle(isOn: $notificationManager.notificationsEnabled) {
                Label {
                    Text("Daily Joke Reminder")
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.accessibleYellow)
                }
            }
            .onChange(of: notificationManager.notificationsEnabled) { _, newValue in
                if newValue && !notificationManager.isAuthorized {
                    requestPermission()
                }
            }

            // Time picker (only show when enabled)
            if notificationManager.notificationsEnabled {
                Button {
                    showingTimePicker.toggle()
                } label: {
                    HStack {
                        Label {
                            Text("Notification Time")
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        Text(notificationManager.formattedTime)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                if showingTimePicker {
                    DatePicker(
                        "Select Time",
                        selection: Binding(
                            get: { notificationManager.notificationTime },
                            set: { notificationManager.notificationTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
            }

            // Permission status warning
            if notificationManager.notificationsEnabled && !notificationManager.isAuthorized {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications Disabled")
                            .font(.subheadline.weight(.medium))
                        Text("Enable in Settings to receive daily jokes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Open Settings") {
                        openSystemSettings()
                    }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get a daily notification with a fresh joke to brighten your day.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private func requestPermission() {
        Task {
            let granted = await notificationManager.requestAuthorization()
            if !granted {
                await MainActor.run {
                    notificationManager.notificationsEnabled = false
                }
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
}
