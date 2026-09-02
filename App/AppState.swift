import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let commandPowerManager: CommandPowerManager
    let powerManager: PowerAssertionManager
    let supervisor: AgentSupervisor
    let networkDiagnostics: NetworkDiagnostics
    let safetyController: PowerSafetyController
    let routeManager: NetworkRouteManager
    let startupManager: AppStartupManager

    private var cancellables: Set<AnyCancellable> = []

    init(
        powerManager: PowerAssertionManager? = nil,
        supervisor: AgentSupervisor? = nil,
        networkDiagnostics: NetworkDiagnostics? = nil
    ) {
        let resolvedPowerManager = powerManager ?? PowerAssertionManager()
        self.commandPowerManager = CommandPowerManager()
        self.powerManager = resolvedPowerManager
        self.safetyController = PowerSafetyController(powerManager: resolvedPowerManager)
        self.routeManager = NetworkRouteManager()
        self.startupManager = AppStartupManager()
        self.supervisor = supervisor ?? AgentSupervisor(powerManager: resolvedPowerManager)
        let resolvedNetworkDiagnostics = networkDiagnostics ?? NetworkDiagnostics()
        self.networkDiagnostics = resolvedNetworkDiagnostics
        resolvedNetworkDiagnostics.start()

        // The menu-bar view only observes AppState. Forward every child
        // manager's change notifications so toggles and status lines update
        // immediately when a mode is enabled or disabled.
        forwardChanges(from: commandPowerManager)
        forwardChanges(from: self.powerManager)
        forwardChanges(from: self.supervisor)
        forwardChanges(from: self.networkDiagnostics)
        forwardChanges(from: safetyController)
        forwardChanges(from: routeManager)
        forwardChanges(from: startupManager)
    }

    private func forwardChanges<Manager: ObservableObject>(from manager: Manager) {
        manager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func enableHeartbeat() {
        let interfaceName = networkDiagnostics.selectedInterfaceName
        if let interfaceName {
            guard routeManager.enable(preferredInterface: interfaceName) else { return }
        }
        commandPowerManager.enableHeartbeat(interfaceName: interfaceName)
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
