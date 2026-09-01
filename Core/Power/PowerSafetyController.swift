import Combine
import Foundation
import IOKit.ps

@MainActor
final class PowerSafetyController: ObservableObject {
    @Published private(set) var settings: SafetySettings
    @Published private(set) var remainingSeconds: Int?
    @Published private(set) var warning: String?

    private weak var powerManager: PowerAssertionManager?
    private var timer: Timer?
    private var startedAt: Date?
    private let settingsURL: URL

    init(powerManager: PowerAssertionManager, settingsURL: URL? = nil) {
        self.powerManager = powerManager
        self.settingsURL = settingsURL ?? Self.defaultURL()
        self.settings = (try? Self.load(from: self.settingsURL).validated()) ?? .default
    }

    func update(_ newSettings: SafetySettings) {
        settings = newSettings.validated()
        try? persist()
        if powerManager?.isActive == true { startMonitoring() }
    }

    func modeWillEnable() -> Bool {
        guard let battery = batteryStatus() else {
            warning = "État de batterie indisponible : vérifie le Mac avant d’activer un mode anti-veille."
            return true
        }
        if settings.requirePowerAdapter && !battery.onACPower {
            warning = "Branche le chargeur avant d’activer ce mode."
            return false
        }
        if battery.percent < settings.minimumBatteryPercent {
            warning = "Batterie trop faible (\(battery.percent) %). Seuil : \(settings.minimumBatteryPercent) %."
            return false
        }
        warning = nil
        return true
    }

    func startMonitoring() {
        startedAt = Date()
        remainingSeconds = settings.maximumDurationMinutes * 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSafety() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        remainingSeconds = nil
        warning = nil
    }

    private func checkSafety() {
        guard powerManager?.isActive == true else {
            stopMonitoring()
            return
        }

        if let startedAt {
            let remaining = max(0, settings.maximumDurationMinutes * 60 - Int(Date().timeIntervalSince(startedAt)))
            remainingSeconds = remaining
            if remaining == 0 {
                warning = "Durée maximale atteinte : Mode Voyage désactivé automatiquement."
                powerManager?.disableKeepAwake()
                stopMonitoring()
                return
            }
        }

        if let battery = batteryStatus() {
            if settings.requirePowerAdapter && !battery.onACPower {
                warning = "Chargeur débranché : Mode Voyage désactivé automatiquement."
                powerManager?.disableKeepAwake()
                stopMonitoring()
            } else if battery.percent < settings.minimumBatteryPercent {
                warning = "Batterie sous le seuil de sécurité : Mode Voyage désactivé automatiquement."
                powerManager?.disableKeepAwake()
                stopMonitoring()
            }
        }
    }

    private struct BatteryStatus {
        let percent: Int
        let onACPower: Bool
    }

    private func batteryStatus() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              let capacity = description[kIOPSCurrentCapacityKey] as? Int,
              let state = description[kIOPSPowerSourceStateKey] as? String else {
            return nil
        }
        return BatteryStatus(percent: capacity, onACPower: state == kIOPSACPowerValue)
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(settings).write(to: settingsURL, options: .atomic)
    }

    private static func load(from url: URL) throws -> SafetySettings {
        try JSONDecoder().decode(SafetySettings.self, from: Data(contentsOf: url))
    }

    private static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("joseph", isDirectory: true)
            .appendingPathComponent("safety-settings.json")
    }

    deinit { timer?.invalidate() }
}
