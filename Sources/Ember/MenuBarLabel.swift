import SwiftUI

/// Wraps `MenuBarIcon` with the side effects that need View environment
/// access (presenting alerts) — the status item's label is the one piece of
/// UI that's always mounted, so it's the natural place to react to
/// `AppState` flags raised from a plain class.
struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        MenuBarIcon(runState: appState.runState)
            .alert("Heads Up", isPresented: $appState.showThermalCaution) {
                Button("Got It", role: .cancel) {}
            } message: {
                Text("Closing the lid restricts airflow. Under heavy load, your Mac may run warmer than usual while the lid is closed. Consider using an auto-off timer if you're not sure how long you'll be away.")
            }
            .alert("Ember Left Your Mac Awake", isPresented: $appState.showCrashRecoveryPrompt) {
                Button("Turn Sleep Back On") { appState.resolveCrashRecovery(turnOff: true) }
                Button("Keep It Awake", role: .cancel) { appState.resolveCrashRecovery(turnOff: false) }
            } message: {
                Text("Ember found your Mac set to never sleep, but has no record of turning that on — likely from a crash or a previous session. Turn normal sleep back on?")
            }
    }
}
