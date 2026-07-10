import Foundation
import ServiceManagement
import UserNotifications

enum EmberRunState: Equatable {
    case idle
    case keepingAwake
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var runState: EmberRunState = .idle
    @Published private(set) var awakeSince: Date?
    @Published private(set) var remainingSeconds: TimeInterval?
    @Published var selectedDuration: KeepAwakeDuration
    @Published var showThermalCaution = false
    @Published var showCrashRecoveryPrompt = false
    @Published var lastErrorMessage: String?
    @Published private(set) var launchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    let settings = EmberSettings.shared
    let backend = AdminPromptBackend()

    private var countdownTimer: Timer?
    private var batteryTimer: Timer?
    private let notificationCenter = UNUserNotificationCenter.current()

    init() {
        selectedDuration = EmberSettings.shared.defaultDuration
        requestNotificationAuthorization()
        startBatteryGuard()
        Task { await reconcileOnLaunch() }
    }

    // MARK: - Launch reconciliation (§5, §6.7)

    /// The kernel flag persists across restarts and crashes, so on launch we
    /// trust `pmset -g`, not our own assumptions, and reconcile the UI to it.
    func reconcileOnLaunch() async {
        do {
            let disabled = try PMSet.isSleepDisabled()
            if disabled {
                runState = .keepingAwake
                if let startedAt = settings.activeSessionStartedAt {
                    awakeSince = startedAt
                    restoreDeadlineTimerIfNeeded()
                } else {
                    // Flag is set but we have no record of starting it —
                    // either Ember crashed last time, or someone ran pmset by hand.
                    showCrashRecoveryPrompt = true
                }
            } else {
                runState = .idle
                clearSessionRecord()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func restoreDeadlineTimerIfNeeded() {
        guard let deadline = settings.activeSessionDeadline else { return }
        if deadline <= .now {
            Task { await disable() }
        } else {
            scheduleCountdown(until: deadline)
        }
    }

    func resolveCrashRecovery(turnOff: Bool) {
        showCrashRecoveryPrompt = false
        if turnOff {
            Task { await disable() }
        } else {
            awakeSince = .now
            settings.activeSessionStartedAt = .now
        }
    }

    // MARK: - Toggle (§5)

    func toggle() {
        switch runState {
        case .keepingAwake:
            Task { await disable() }
        default:
            Task { await enable() }
        }
    }

    func enable() async {
        if !settings.hasShownThermalCaution {
            showThermalCaution = true
            settings.hasShownThermalCaution = true
        }
        do {
            try await backend.setKeepAwake(true)
            runState = .keepingAwake
            awakeSince = .now
            settings.activeSessionStartedAt = .now
            if let seconds = selectedDuration.seconds {
                let deadline = Date.now.addingTimeInterval(seconds)
                settings.activeSessionDeadline = deadline
                scheduleCountdown(until: deadline)
            } else {
                settings.activeSessionDeadline = nil
                remainingSeconds = nil
            }
            notify(title: "Ember is keeping your Mac awake", body: "Sleep is disabled, even with the lid closed.")
        } catch {
            runState = .error(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
        }
    }

    func disable() async {
        do {
            try await backend.setKeepAwake(false)
            runState = .idle
            clearSessionRecord()
            notify(title: "Ember turned off", body: "Normal sleep behavior is restored.")
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Called from the "Quit Ember" action / Cmd+Q override before the app
    /// actually terminates. Default behavior is to restore sleep (§5, §6.1).
    func prepareForQuit() async {
        guard runState == .keepingAwake, !settings.keepAwakeAfterQuit else { return }
        await disable()
    }

    private func clearSessionRecord() {
        awakeSince = nil
        remainingSeconds = nil
        settings.activeSessionStartedAt = nil
        settings.activeSessionDeadline = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Countdown timer

    private func scheduleCountdown(until deadline: Date) {
        countdownTimer?.invalidate()
        remainingSeconds = deadline.timeIntervalSinceNow
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let remaining = deadline.timeIntervalSinceNow
                if remaining <= 0 {
                    self.remainingSeconds = 0
                    await self.disable()
                } else {
                    self.remainingSeconds = remaining
                }
            }
        }
    }

    // MARK: - Low battery guard (§6.3)

    private func startBatteryGuard() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkBattery() }
        }
    }

    private func checkBattery() {
        guard settings.lowBatteryGuardEnabled, runState == .keepingAwake else { return }
        guard let status = BatteryStatus.read(), !status.isOnACPower else { return }
        guard status.percentage <= settings.lowBatteryThreshold else { return }
        Task {
            await disable()
            notify(
                title: "Ember turned off — low battery",
                body: "Battery dropped to \(status.percentage)%. Sleep has been restored to protect your Mac."
            )
        }
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        Task {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Notifications

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        guard settings.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        notificationCenter.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
