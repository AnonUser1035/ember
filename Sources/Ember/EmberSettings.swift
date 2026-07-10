import Foundation
import Combine

/// Persisted user preferences, backed by UserDefaults. All defaults are
/// chosen to be the *safe* option (§6 of the spec) — sleep gets restored
/// unless the user explicitly opts out.
final class EmberSettings: ObservableObject {
    static let shared = EmberSettings()

    private enum Keys {
        static let keepAwakeAfterQuit = "keepAwakeAfterQuit"
        static let lowBatteryGuardEnabled = "lowBatteryGuardEnabled"
        static let lowBatteryThreshold = "lowBatteryThreshold"
        static let notificationsEnabled = "notificationsEnabled"
        static let defaultDuration = "defaultDuration"
        static let hasShownThermalCaution = "hasShownThermalCaution"
        static let activeSessionStartedAt = "activeSessionStartedAt"
        static let activeSessionDeadline = "activeSessionDeadline"
    }

    private let defaults: UserDefaults

    /// "Keep awake even after I quit Ember" — default OFF (safe: quitting restores sleep).
    @Published var keepAwakeAfterQuit: Bool {
        didSet { defaults.set(keepAwakeAfterQuit, forKey: Keys.keepAwakeAfterQuit) }
    }

    @Published var lowBatteryGuardEnabled: Bool {
        didSet { defaults.set(lowBatteryGuardEnabled, forKey: Keys.lowBatteryGuardEnabled) }
    }

    /// Percentage (0-100) at which the low-battery guard trips.
    @Published var lowBatteryThreshold: Int {
        didSet { defaults.set(lowBatteryThreshold, forKey: Keys.lowBatteryThreshold) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var defaultDuration: KeepAwakeDuration {
        didSet { defaults.set(defaultDuration.rawValue, forKey: Keys.defaultDuration) }
    }

    @Published var hasShownThermalCaution: Bool {
        didSet { defaults.set(hasShownThermalCaution, forKey: Keys.hasShownThermalCaution) }
    }

    /// When Ember itself started the current keep-awake session. Used to
    /// distinguish a normal session from crash-recovery (flag set, no record).
    var activeSessionStartedAt: Date? {
        get { defaults.object(forKey: Keys.activeSessionStartedAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.activeSessionStartedAt) }
    }

    /// When the auto-off timer should fire, if a finite duration was chosen.
    var activeSessionDeadline: Date? {
        get { defaults.object(forKey: Keys.activeSessionDeadline) as? Date }
        set { defaults.set(newValue, forKey: Keys.activeSessionDeadline) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keepAwakeAfterQuit = defaults.object(forKey: Keys.keepAwakeAfterQuit) as? Bool ?? false
        self.lowBatteryGuardEnabled = defaults.object(forKey: Keys.lowBatteryGuardEnabled) as? Bool ?? true
        self.lowBatteryThreshold = defaults.object(forKey: Keys.lowBatteryThreshold) as? Int ?? 20
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.hasShownThermalCaution = defaults.bool(forKey: Keys.hasShownThermalCaution)
        if let raw = defaults.string(forKey: Keys.defaultDuration), let duration = KeepAwakeDuration(rawValue: raw) {
            self.defaultDuration = duration
        } else {
            self.defaultDuration = .indefinite
        }
    }
}
