import Foundation
import IOKit.pwr_mgt

protocol PowerAssertionProviding {
    func create(type: CFString, reason: CFString) -> (IOReturn, IOPMAssertionID)
    func release(_ assertionID: IOPMAssertionID) -> IOReturn
}

struct IOKitPowerAssertionProvider: PowerAssertionProviding {
    func create(type: CFString, reason: CFString) -> (IOReturn, IOPMAssertionID) {
        var identifier = kIOPMNullAssertionID
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &identifier
        )
        return (result, identifier)
    }

    func release(_ assertionID: IOPMAssertionID) -> IOReturn {
        IOPMAssertionRelease(assertionID)
    }
}

@MainActor
final class PowerAssertionManager: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var lastError: String?

    private let provider: PowerAssertionProviding
    private var systemSleepAssertionID = kIOPMNullAssertionID
    private var idleSleepAssertionID = kIOPMNullAssertionID
    private var activeReason: String?

    init(provider: PowerAssertionProviding = IOKitPowerAssertionProvider()) {
        self.provider = provider
    }

    @discardableResult
    func enableKeepAwake(reason: String = "JOSEPH: Running Headless Tasks") -> Bool {
        guard !isActive else { return true }

        let systemResult = provider.create(
            type: kIOPMAssertionTypePreventSystemSleep as CFString,
            reason: reason as CFString
        )
        guard systemResult.0 == kIOReturnSuccess else {
            lastError = "PreventSystemSleep failed: 0x\(String(systemResult.0, radix: 16))"
            josephLog("ERROR", lastError ?? "Power assertion failed")
            return false
        }
        systemSleepAssertionID = systemResult.1

        let idleResult = provider.create(
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            reason: reason as CFString
        )
        if idleResult.0 == kIOReturnSuccess {
            idleSleepAssertionID = idleResult.1
        } else {
            josephLog("WARN", "PreventUserIdleSystemSleep failed: 0x\(String(idleResult.0, radix: 16))")
        }

        activeReason = reason
        lastError = nil
        isActive = true
        josephLog("INFO", "Keep-awake enabled: \(reason)")
        return true
    }

    func disableKeepAwake() {
        guard isActive || systemSleepAssertionID != kIOPMNullAssertionID || idleSleepAssertionID != kIOPMNullAssertionID else { return }
        if systemSleepAssertionID != kIOPMNullAssertionID {
            _ = provider.release(systemSleepAssertionID)
            systemSleepAssertionID = kIOPMNullAssertionID
        }
        if idleSleepAssertionID != kIOPMNullAssertionID {
            _ = provider.release(idleSleepAssertionID)
            idleSleepAssertionID = kIOPMNullAssertionID
        }
        josephLog("INFO", "Keep-awake disabled (was: \(activeReason ?? "n/a"))")
        activeReason = nil
        isActive = false
    }

    var currentReason: String? { activeReason }

    deinit {
        if systemSleepAssertionID != kIOPMNullAssertionID { _ = provider.release(systemSleepAssertionID) }
        if idleSleepAssertionID != kIOPMNullAssertionID { _ = provider.release(idleSleepAssertionID) }
    }
}

func josephLog(_ level: String, _ message: String) {
    let formatter = ISO8601DateFormatter()
    let line = "[\(formatter.string(from: Date()))] [\(level)] \(message)\n"
    FileHandle.standardOutput.write(Data(line.utf8))

    let directory = URL(fileURLWithPath: "~/.joseph/logs".expandingTildeInPath)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("joseph.log")
        if FileManager.default.fileExists(atPath: file.path), let handle = try? FileHandle(forWritingTo: file) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            try handle.close()
        } else {
            try Data(line.utf8).write(to: file, options: .atomic)
        }
    } catch {
        // stdout remains available when the runtime log cannot be written.
    }
}

private extension String {
    var expandingTildeInPath: String { (self as NSString).expandingTildeInPath }
}
