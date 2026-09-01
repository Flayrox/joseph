import Foundation

struct SafetySettings: Codable, Equatable {
    var maximumDurationMinutes: Int = 120
    var minimumBatteryPercent: Int = 20
    var requirePowerAdapter: Bool = false

    static let `default` = SafetySettings()

    func validated() -> SafetySettings {
        var copy = self
        copy.maximumDurationMinutes = min(max(copy.maximumDurationMinutes, 5), 24 * 60)
        copy.minimumBatteryPercent = min(max(copy.minimumBatteryPercent, 0), 100)
        return copy
    }
}
