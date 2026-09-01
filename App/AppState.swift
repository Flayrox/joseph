import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let powerManager: PowerAssertionManager
    let supervisor: AgentSupervisor

    init(
        powerManager: PowerAssertionManager = PowerAssertionManager(),
        supervisor: AgentSupervisor = AgentSupervisor()
    ) {
        self.powerManager = powerManager
        self.supervisor = supervisor
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
