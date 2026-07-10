import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = EmberSettings.shared

    var body: some View {
        Form {
            Section("Behavior") {
                Picker("Default duration", selection: $settings.defaultDuration) {
                    ForEach(KeepAwakeDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
                Toggle("Keep awake even after I quit Ember", isOn: $settings.keepAwakeAfterQuit)
                    .help("Off (default) means quitting Ember always restores normal sleep.")
            }

            Section("Battery") {
                Toggle("Turn off automatically on low battery", isOn: $settings.lowBatteryGuardEnabled)
                if settings.lowBatteryGuardEnabled {
                    Stepper(value: $settings.lowBatteryThreshold, in: 5...50, step: 5) {
                        Text("Threshold: \(settings.lowBatteryThreshold)%")
                    }
                }
            }

            Section("Notifications") {
                Toggle("Notify when Ember turns on or off", isOn: $settings.notificationsEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
