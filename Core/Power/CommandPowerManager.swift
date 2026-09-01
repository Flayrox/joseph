import Combine
import Foundation

struct CommandResult {
    let status: Int32
    let output: String
}

protocol CommandRunning {
    func run(path: String, arguments: [String], capturesOutput: Bool, requiresAdministrator: Bool) throws -> CommandResult
    func start(path: String, arguments: [String], redirectsOutput: Bool) throws -> Process
}

struct FoundationCommandRunner: CommandRunning {
    func run(
        path: String,
        arguments: [String],
        capturesOutput: Bool,
        requiresAdministrator: Bool
    ) throws -> CommandResult {
        if requiresAdministrator {
            guard path == "/usr/bin/pmset" else {
                throw CommandPowerError.privilegedCommandNotAllowed(path)
            }
            return try runWithAdministratorPrivileges(path: path, arguments: arguments)
        }

        return try execute(path: path, arguments: arguments, capturesOutput: capturesOutput)
    }

    func start(path: String, arguments: [String], redirectsOutput: Bool) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if redirectsOutput {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }
        try process.run()
        return process
    }

    private func runWithAdministratorPrivileges(path: String, arguments: [String]) throws -> CommandResult {
        let command = ([path] + arguments).map(Self.shellQuote).joined(separator: " ")
        let script = "do shell script \(Self.appleScriptQuote(command)) with administrator privileges"
        return try execute(path: "/usr/bin/osascript", arguments: ["-e", script], capturesOutput: true)
    }

    private func execute(path: String, arguments: [String], capturesOutput: Bool) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = capturesOutput ? Pipe() : nil
        process.standardOutput = pipe ?? FileHandle.nullDevice
        process.standardError = pipe ?? FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let output = pipe.map { String(decoding: $0.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) } ?? ""
        return CommandResult(status: process.terminationStatus, output: output)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

enum CommandPowerError: LocalizedError, Equatable {
    case commandFailed(String, Int32)
    case invalidSettings(String)
    case privilegedCommandNotAllowed(String)
    case snapshotPersistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(command, status):
            return "\(command) failed (status \(status)). Administrator authorization may be required."
        case let .invalidSettings(message):
            return "Invalid power settings: \(message)"
        case let .privilegedCommandNotAllowed(path):
            return "Refusing to run an unapproved privileged command: \(path)"
        case let .snapshotPersistenceFailed(message):
            return "Could not save the power-settings snapshot: \(message)"
        }
    }
}

struct PMSetPowerSettings: Codable, Equatable {
    let batterySleep: String
    let batteryDisplaySleep: String
    let chargerSleep: String
    let chargerDisplaySleep: String
    let disableSleep: String

    static func parse(from output: String) throws -> PMSetPowerSettings {
        enum Profile: String { case battery, charger }

        var profile: Profile?
        var values: [String: String] = [:]
        var disableSleep: String?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "Battery Power:" {
                profile = .battery
                continue
            }
            if line == "AC Power:" {
                profile = .charger
                continue
            }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else { continue }
            let key = String(parts[0]).lowercased()
            let value = String(parts[1])

            if key == "disablesleep" {
                disableSleep = value
            } else if (key == "sleep" || key == "displaysleep"), let profile {
                values["\(profile.rawValue).\(key)"] = value
            }
        }

        let settings = PMSetPowerSettings(
            batterySleep: try requiredValue("battery.sleep", from: values),
            batteryDisplaySleep: try requiredValue("battery.displaysleep", from: values),
            chargerSleep: try requiredValue("charger.sleep", from: values),
            chargerDisplaySleep: try requiredValue("charger.displaysleep", from: values),
            disableSleep: disableSleep ?? "0"
        )
        try settings.validate()
        return settings
    }

    func validate() throws {
        for (name, value) in [
            ("battery sleep", batterySleep),
            ("battery display sleep", batteryDisplaySleep),
            ("charger sleep", chargerSleep),
            ("charger display sleep", chargerDisplaySleep),
            ("disable sleep", disableSleep)
        ] {
            guard value.allSatisfy(\.isNumber), Int(value) != nil else {
                throw CommandPowerError.invalidSettings("\(name)=\(value)")
            }
        }
    }

    private static func requiredValue(_ key: String, from values: [String: String]) throws -> String {
        guard let value = values[key] else {
            throw CommandPowerError.invalidSettings("missing \(key)")
        }
        return value
    }
}

@MainActor
final class CommandPowerManager: ObservableObject {
    @Published private(set) var isPMSetEnabled = false
    @Published private(set) var isCaffeinateEnabled = false
    @Published private(set) var isHeartbeatEnabled = false
    @Published private(set) var pmsetStatus = "Disabled"
    @Published private(set) var caffeinateStatus = "Disabled"
    @Published private(set) var heartbeatStatus = "Disabled"
    @Published private(set) var lastError: String?

    private static let pmsetPath = "/usr/bin/pmset"
    private static let caffeinatePath = "/usr/bin/caffeinate"
    private static let pingPath = "/sbin/ping"

    private let runner: CommandRunning
    private let snapshotURL: URL
    private var originalSettings: PMSetPowerSettings?
    private var caffeinateProcess: Process?
    private var heartbeatProcess: Process?

    init(runner: CommandRunning = FoundationCommandRunner(), snapshotURL: URL? = nil) {
        self.runner = runner
        self.snapshotURL = snapshotURL ?? Self.defaultSnapshotURL()

        if let snapshot = try? Self.readSnapshot(at: self.snapshotURL) {
            originalSettings = snapshot
            isPMSetEnabled = true
            pmsetStatus = "Restore required"
            lastError = "A previous joseph session left a power-settings snapshot. Disable pmset mode to restore it."
        }
    }

    // MARK: - pmset

    func enablePMSet() {
        guard !isPMSetEnabled else { return }

        do {
            let settings = try readCurrentSettings()
            try persistSnapshot(settings)
            originalSettings = settings

            do {
                try applyPMSetMode()
            } catch {
                do {
                    try restore(settings)
                    try removeSnapshot()
                    originalSettings = nil
                } catch {
                    isPMSetEnabled = true
                    pmsetStatus = "Restore required"
                    lastError = "pmset activation failed and rollback also failed: \(error.localizedDescription)"
                    josephLog("CRITICAL", lastError ?? "pmset rollback failed")
                    return
                }
                throw error
            }

            isPMSetEnabled = true
            pmsetStatus = "Enabled"
            lastError = nil
            josephLog("INFO", "pmset command mode enabled")
        } catch {
            isPMSetEnabled = false
            pmsetStatus = "Error"
            lastError = error.localizedDescription
            josephLog("ERROR", "pmset command mode failed: \(error.localizedDescription)")
        }
    }

    func disablePMSet() {
        guard let settings = originalSettings ?? (try? Self.readSnapshot(at: snapshotURL)) else {
            isPMSetEnabled = false
            pmsetStatus = "Disabled"
            return
        }

        do {
            try restore(settings)
            try removeSnapshot()
            originalSettings = nil
            isPMSetEnabled = false
            pmsetStatus = "Disabled"
            lastError = nil
            josephLog("INFO", "pmset command mode disabled; original settings restored")
        } catch {
            isPMSetEnabled = true
            pmsetStatus = "Restore required"
            lastError = "Could not restore power settings: \(error.localizedDescription)"
            josephLog("CRITICAL", lastError ?? "Power settings restore failed")
        }
    }

    // MARK: - caffeinate

    func enableCaffeinate() {
        guard !isCaffeinateEnabled else { return }
        do {
            let process = try runner.start(path: Self.caffeinatePath, arguments: ["-d"], redirectsOutput: true)
            process.terminationHandler = { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.caffeinateProcess === process else { return }
                    self.caffeinateProcess = nil
                    self.isCaffeinateEnabled = false
                    self.caffeinateStatus = "Exited"
                }
            }
            caffeinateProcess = process
            isCaffeinateEnabled = true
            caffeinateStatus = "Enabled"
            lastError = nil
            josephLog("INFO", "caffeinate -d enabled")
        } catch {
            isCaffeinateEnabled = false
            caffeinateStatus = "Error"
            lastError = "Could not start caffeinate: \(error.localizedDescription)"
            josephLog("ERROR", lastError ?? "caffeinate failed")
        }
    }

    func disableCaffeinate() {
        stop(process: caffeinateProcess)
        caffeinateProcess = nil
        isCaffeinateEnabled = false
        caffeinateStatus = "Disabled"
        josephLog("INFO", "caffeinate -d disabled")
    }

    // MARK: - Heartbeat

    func enableHeartbeat() {
        guard !isHeartbeatEnabled else { return }
        do {
            let process = try runner.start(
                path: Self.pingPath,
                arguments: ["-i", "15", "1.1.1.1"],
                redirectsOutput: true
            )
            process.terminationHandler = { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.heartbeatProcess === process else { return }
                    self.heartbeatProcess = nil
                    self.isHeartbeatEnabled = false
                    self.heartbeatStatus = "Exited"
                }
            }
            heartbeatProcess = process
            isHeartbeatEnabled = true
            heartbeatStatus = "Enabled"
            lastError = nil
            josephLog("INFO", "heartbeat ping enabled")
        } catch {
            isHeartbeatEnabled = false
            heartbeatStatus = "Error"
            lastError = "Could not start heartbeat: \(error.localizedDescription)"
            josephLog("ERROR", lastError ?? "heartbeat failed")
        }
    }

    func disableHeartbeat() {
        stop(process: heartbeatProcess)
        heartbeatProcess = nil
        isHeartbeatEnabled = false
        heartbeatStatus = "Disabled"
        josephLog("INFO", "heartbeat ping disabled")
    }

    func disableAll() {
        disableHeartbeat()
        disableCaffeinate()
        disablePMSet()
    }

    // MARK: - Internals

    private func readCurrentSettings() throws -> PMSetPowerSettings {
        let result = try runner.run(path: Self.pmsetPath, arguments: ["-g", "custom"], capturesOutput: true, requiresAdministrator: false)
        guard result.status == 0 else {
            throw CommandPowerError.commandFailed("pmset -g custom", result.status)
        }
        return try PMSetPowerSettings.parse(from: result.output)
    }

    private func applyPMSetMode() throws {
        try runPMSet(arguments: ["-c", "sleep", "0", "displaysleep", "0"], requiresAdministrator: true)
        try runPMSet(arguments: ["-a", "disablesleep", "1"], requiresAdministrator: true)
    }

    private func restore(_ settings: PMSetPowerSettings) throws {
        try settings.validate()
        try runPMSet(arguments: ["-b", "sleep", settings.batterySleep, "displaysleep", settings.batteryDisplaySleep], requiresAdministrator: true)
        try runPMSet(arguments: ["-c", "sleep", settings.chargerSleep, "displaysleep", settings.chargerDisplaySleep], requiresAdministrator: true)
        try runPMSet(arguments: ["-a", "disablesleep", settings.disableSleep], requiresAdministrator: true)
    }

    private func runPMSet(arguments: [String], requiresAdministrator: Bool) throws {
        let result = try runner.run(path: Self.pmsetPath, arguments: arguments, capturesOutput: false, requiresAdministrator: requiresAdministrator)
        guard result.status == 0 else {
            throw CommandPowerError.commandFailed("pmset", result.status)
        }
    }

    private func persistSnapshot(_ settings: PMSetPowerSettings) throws {
        do {
            try FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: snapshotURL, options: .atomic)
        } catch {
            throw CommandPowerError.snapshotPersistenceFailed(error.localizedDescription)
        }
    }

    private func removeSnapshot() throws {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        try FileManager.default.removeItem(at: snapshotURL)
    }

    private func stop(process: Process?) {
        guard let process, process.isRunning else { return }
        process.terminationHandler = nil
        process.terminate()
    }

    private static func defaultSnapshotURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("joseph", isDirectory: true)
            .appendingPathComponent("pmset-snapshot.json")
    }

    private static func readSnapshot(at url: URL) throws -> PMSetPowerSettings {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PMSetPowerSettings.self, from: data)
    }

    deinit {
        if let process = caffeinateProcess, process.isRunning { process.terminate() }
        if let process = heartbeatProcess, process.isRunning { process.terminate() }
    }
}
