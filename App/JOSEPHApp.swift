import SwiftUI

@main
struct JOSEPHApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("joseph", systemImage: state.powerManager.isActive || state.commandPowerManager.isPMSetEnabled ? "bolt.fill" : "bolt.slash") {
            Text("joseph")
                .font(.headline)

            Divider()

            Toggle("Mode Voyage (assertion native)", isOn: Binding(
                get: { state.isPowerModeEnabled },
                set: { state.isPowerModeEnabled = $0 }
            ))

            Toggle("pmset : bloquer la veille", isOn: Binding(
                get: { state.commandPowerManager.isPMSetEnabled },
                set: { $0 ? state.commandPowerManager.enablePMSet() : state.commandPowerManager.disablePMSet() }
            ))

            Toggle("caffeinate : garder l’écran actif", isOn: Binding(
                get: { state.commandPowerManager.isCaffeinateEnabled },
                set: { $0 ? state.commandPowerManager.enableCaffeinate() : state.commandPowerManager.disableCaffeinate() }
            ))

            Toggle("Heartbeat : ping toutes les 15 s", isOn: Binding(
                get: { state.commandPowerManager.isHeartbeatEnabled },
                set: { $0 ? state.commandPowerManager.enableHeartbeat() : state.commandPowerManager.disableHeartbeat() }
            ))

            VStack(alignment: .leading, spacing: 2) {
                Text("pmset : \(state.commandPowerManager.pmsetStatus)")
                Text("caffeinate : \(state.commandPowerManager.caffeinateStatus)")
                Text("heartbeat : \(state.commandPowerManager.heartbeatStatus)")
            }
            .font(.caption)

            if let error = state.commandPowerManager.lastError ?? state.powerManager.lastError ?? state.supervisor.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Menu("Processus & Agents") {
                Button("Lancer un agent…") {
                    _ = state.supervisor.launch(executable: "/usr/bin/true")
                }
                Button("Arrêter tous les processus") {
                    state.supervisor.terminateAll()
                }
                .disabled(state.supervisor.processes.isEmpty)
            }

            Text("Processus actifs : \(state.supervisor.processes.filter { $0.status == .running }.count)")
                .font(.caption)
            Text("Réseau : \(state.networkDiagnostics.pathStatus)")
                .font(.caption)

            Divider()

            Button("Quitter") {
                state.supervisor.terminateAll()
                state.commandPowerManager.disableAll()
                state.powerManager.disableKeepAwake()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.window)
    }
}
