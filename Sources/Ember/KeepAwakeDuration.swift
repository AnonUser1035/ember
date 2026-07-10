import Foundation

enum KeepAwakeDuration: String, CaseIterable, Identifiable {
    case indefinite
    case thirtyMinutes
    case oneHour
    case twoHours
    case fiveHours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .indefinite: return "Indefinitely"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        case .fiveHours: return "5 Hours"
        }
    }

    /// `nil` means no automatic timeout.
    var seconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fiveHours: return 5 * 60 * 60
        }
    }
}
