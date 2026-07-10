import Foundation
import IOKit.ps

/// Unprivileged battery/AC-power read used by the low-battery guard (§6.3).
enum BatteryStatus {
    /// Returns (percentage 0-100, isOnACPower). `nil` if no power source is available
    /// (e.g. a Mac with no battery).
    static func read() -> (percentage: Int, isOnACPower: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0 else {
                continue
            }
            let percentage = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
            let state = description[kIOPSPowerSourceStateKey] as? String
            let isOnACPower = state == kIOPSACPowerValue
            return (percentage, isOnACPower)
        }
        return nil
    }
}
