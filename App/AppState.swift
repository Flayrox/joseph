import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let powerManager: PowerAssertionManager
    let supervisor: AgentSupervisor
    let networkDiagnostics: NetworkDiagnostics

    init(
        powerManager: PowerAssertionManager? = nil,
        supervisor: AgentSupervisor? = nil,
        networkDiagnostics: NetworkDiagnostics? = nil
    ) {
        let resolvedPowerManager = powerManager ?? PowerAssertionManager()
        self.powerManager = resolvedPowerManager
        self.supervisor = supervisor ?? AgentSupervisor(powerManager: resolvedPowerManager)
        let resolvedNetworkDiagnostics = networkDiagnostics ?? NetworkDiagnostics()
        self.networkDiagnostics = resolvedNetworkDiagnostics
        resolvedNetworkDiagnostics.start()
    }

    var isPowerModeEnabled: Bool {
        get { powerManager.isActive }
        set {
            if newValue {
                _ = powerManager.enableKeepAwake(reason: "JOSEPH: Travel mode")
            } else {
                powerManager.disableKeepAwake()
            }
        }
    }
}
