import Foundation
import ServiceManagement

@MainActor
final class AppStartupManager: ObservableObject {
    @Published private(set) var launchesAtLogin: Bool
    @Published private(set) var status: String?

    init() {
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchesAtLogin = SMAppService.mainApp.status == .enabled
            status = nil
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
            status = error.localizedDescription
        }
    }
}
