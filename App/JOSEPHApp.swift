import SwiftUI

@main
struct josephApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("joseph", systemImage: state.powerManager.isActive || state.commandPowerManager.isPMSetEnabled ? "bolt.fill" : "bolt.slash") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    JosephOutlineLogo()
                        .frame(width: 24, height: 24)
                    Text("joseph")
                        .font(.headline)
                }

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
                    Text("réseau : \(state.networkDiagnostics.pathStatus)")
                }
                .font(.caption)

                if let error = state.commandPowerManager.lastError ?? state.powerManager.lastError ?? state.supervisor.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                Button("Lancer un agent…") { openAgentLauncher() }
                ProcessListView(supervisor: state.supervisor)
                Divider()
                Button("Quitter") {
                    state.supervisor.terminateAll()
                    state.commandPowerManager.disableAll()
                    state.powerManager.disableKeepAwake()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(12)
        }
        .menuBarExtraStyle(.window)

        Window("Lancer un agent", id: "agent-launcher") {
            VStack(spacing: 12) {
                JosephFilledLogo()
                    .frame(width: 72, height: 72)
                AgentLaunchView(supervisor: state.supervisor)
            }
            .padding()
        }
        .defaultSize(width: 420, height: 160)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Lancer un agent…") { openAgentLauncher() }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
        }
    }

    private func openAgentLauncher() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(#selector(NSWindowController.showWindow(_:)), to: nil, from: nil)
    }

}
