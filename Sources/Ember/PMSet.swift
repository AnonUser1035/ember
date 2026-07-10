import Foundation

enum PMSetError: LocalizedError {
    case processFailed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let status, let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "pmset exited with status \(status)" : trimmed
        }
    }
}

/// Thin wrapper around `/usr/bin/pmset`. Reading (`-g`) needs no privilege;
/// writing (`-a disablesleep`) needs root, which `AdminPromptBackend` gets via
/// an admin-authenticated AppleScript rather than calling this directly.
enum PMSet {
    static let executablePath = "/usr/bin/pmset"

    /// Unprivileged read of the kernel `SleepDisabled` flag.
    static func isSleepDisabled() throws -> Bool {
        parseSleepDisabled(from: try run(["-g"]))
    }

    static func parseSleepDisabled(from output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SleepDisabled") {
                return trimmed.hasSuffix("1")
            }
        }
        return false
    }

    @discardableResult
    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw PMSetError.processFailed(status: process.terminationStatus, output: err.isEmpty ? out : err)
        }
        return out
    }
}
