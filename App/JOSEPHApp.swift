import SwiftUI

@main
struct JOSEPHApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("JOSEPH", systemImage: state.powerManager.isActive ? "bolt.fill" : "bolt.slash") {
            Text("J.O.S.E.P.H.")
                .font(.headline)

            Divider()

            Toggle("Mode Voyage", isOn: Binding(
                get: { state.isPowerModeEnabled },
                set: { state.isPowerModeEnabled = $0 }
            ))

            if let error = state.powerManager.lastError ?? state.supervisor.lastError {
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
                state.powerManager.disableKeepAwake()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.window)
    }
}
