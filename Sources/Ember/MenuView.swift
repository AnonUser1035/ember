import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            toggleRow

            if appState.runState == .keepingAwake {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            if let message = appState.lastErrorMessage {
                Text(message)
                    .foregroundStyle(.red)
            }

            Menu("Keep Awake For") {
                ForEach(KeepAwakeDuration.allCases) { duration in
                    Button {
                        appState.selectedDuration = duration
                    } label: {
                        if appState.selectedDuration == duration {
                            Label(duration.label, systemImage: "checkmark")
                        } else {
                            Text(duration.label)
                        }
                    }
                }
            }

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { appState.launchAtLoginEnabled },
                set: { appState.setLaunchAtLogin($0) }
            ))

            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }

            Button("About Ember") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
            }

            Divider()

            Button("Quit Ember") {
                Task {
                    await appState.prepareForQuit()
                    NSApp.terminate(nil)
                }
            }
        }
    }

    @ViewBuilder
    private var toggleRow: some View {
        Button {
            appState.toggle()
        } label: {
            if appState.runState == .keepingAwake {
                Label("Keep Awake", systemImage: "checkmark")
            } else {
                Text("Keep Awake")
            }
        }
    }

    private var subtitle: String {
        var parts = ["Awake — lid can stay closed"]
        if let awakeSince = appState.awakeSince {
            parts.append("· " + formatDuration(Date.now.timeIntervalSince(awakeSince)))
        }
        if let remaining = appState.remainingSeconds {
            parts.append("(\(formatDuration(remaining)) left)")
        }
        return parts.joined(separator: " ")
    }
}

func formatDuration(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 {
        return String(format: "%dh %02dm", hours, minutes)
    }
    return String(format: "%dm", minutes)
}
