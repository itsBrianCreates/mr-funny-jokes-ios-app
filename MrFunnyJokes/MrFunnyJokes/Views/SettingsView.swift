import SwiftUI
import AppIntents

struct SettingsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                notificationSection
                siriSection
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

            // Manage Notifications button (only show when enabled)
            if notificationManager.notificationsEnabled {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label {
                            Text("Manage Notifications")
                        } icon: {
                            Image(systemName: "gear")
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
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
            Text("Want to adjust when you get jokes? Tap above to manage your notification preferences in Settings.")
        }
    }

    // MARK: - Siri Section

    private var siriSection: some View {
        Section {
            SiriTipView(intent: TellJokeIntent())
                .siriTipViewStyle(.automatic)
        } header: {
            Text("Siri")
        } footer: {
            Text("Say this to get a random joke without opening the app.")
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
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
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
