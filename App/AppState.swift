import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let commandPowerManager: CommandPowerManager
    let powerManager: PowerAssertionManager
    let supervisor: AgentSupervisor
    let networkDiagnostics: NetworkDiagnostics
    let safetyController: PowerSafetyController

    init(
        powerManager: PowerAssertionManager? = nil,
        supervisor: AgentSupervisor? = nil,
        networkDiagnostics: NetworkDiagnostics? = nil
    ) {
        let resolvedPowerManager = powerManager ?? PowerAssertionManager()
        self.commandPowerManager = CommandPowerManager()
        self.powerManager = resolvedPowerManager
        self.safetyController = PowerSafetyController(powerManager: resolvedPowerManager)
        self.supervisor = supervisor ?? AgentSupervisor(powerManager: resolvedPowerManager)
        let resolvedNetworkDiagnostics = networkDiagnostics ?? NetworkDiagnostics()
        self.networkDiagnostics = resolvedNetworkDiagnostics
        resolvedNetworkDiagnostics.start()
    }

    var isPowerModeEnabled: Bool {
        get { powerManager.isActive }
        set {
            if newValue {
                guard safetyController.modeWillEnable() else { return }
                if powerManager.enableKeepAwake(reason: "joseph: Mode Voyage") {
                    safetyController.startMonitoring()
                }
            } else {
                powerManager.disableKeepAwake()
                safetyController.stopMonitoring()
            }
        }
    }
}
