import Foundation

/// Authorizes each toggle with a native admin password prompt via
/// `do shell script ... with administrator privileges`, exactly like running
/// `sudo pmset -a disablesleep 1` by hand. This is Ember's only way to flip
/// the flag: no privileged helper, no code-signing requirements, just a
/// password prompt on every toggle.
@MainActor
final class AdminPromptBackend {
    func setKeepAwake(_ enabled: Bool) async throws {
        let value = enabled ? "1" : "0"
        let source = "do shell script \"\(PMSet.executablePath) -a disablesleep \(value)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            throw AdminPromptError.scriptCompileFailed
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "AppleScript error"
            throw AdminPromptError.appleScriptFailed(number: number, message: message)
        }
    }
}

enum AdminPromptError: LocalizedError {
    case scriptCompileFailed
    case appleScriptFailed(number: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .scriptCompileFailed:
            return "Could not prepare the system command."
        case .appleScriptFailed(let number, let message):
            // -128 is AppleScript's "user cancelled" error number.
            return number == -128 ? "Cancelled — the password prompt was dismissed." : message
        }
    }
}
