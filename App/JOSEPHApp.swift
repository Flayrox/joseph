import SwiftUI

@main
struct josephApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

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
                Toggle(isOn: Binding(
                    get: { state.isPowerModeEnabled },
                    set: { state.isPowerModeEnabled = $0 }
                )) {
                    ModeLabel(
                        title: "Mode Voyage (assertion native)",
                        explanation: "Empêche le Mac de se mettre en veille tant que ce bouton est activé. Ce mode utilise l’API native de macOS, ne modifie pas les réglages permanents et ne lance aucun processus. Il concerne la veille du système, pas spécifiquement l’écran."
                    )
                }
                Toggle(isOn: Binding(
                    get: { state.commandPowerManager.isPMSetEnabled },
                    set: { $0 ? state.commandPowerManager.enablePMSet() : state.commandPowerManager.disablePMSet() }
                )) {
                    ModeLabel(
                        title: "pmset : bloquer la veille",
                        explanation: "Empêche le Mac de se mettre en veille et garde l’écran allumé en modifiant temporairement les réglages pmset. Les valeurs existantes sont sauvegardées puis restaurées à la désactivation. C’est le mode le plus puissant et il peut augmenter fortement la consommation et la température. Le fonctionnement capot fermé dépend toujours du Mac et de macOS."
                    )
                }
                Toggle(isOn: Binding(
                    get: { state.commandPowerManager.isCaffeinateEnabled },
                    set: { $0 ? state.commandPowerManager.enableCaffeinate() : state.commandPowerManager.disableCaffeinate() }
                )) {
                    ModeLabel(
                        title: "caffeinate : garder l’écran actif",
                        explanation: "Empêche l’écran de s’éteindre tant que caffeinate est activé. Le Mac peut malgré tout se mettre en veille ; l’écran reste simplement allumé. Aucun réglage permanent n’est modifié et le processus est arrêté à la désactivation."
                    )
                }
                Toggle(isOn: Binding(
                    get: { state.commandPowerManager.isHeartbeatEnabled },
                    set: { enabled in
                        if enabled {
                            state.enableHeartbeat()
                        } else {
                            state.commandPowerManager.disableHeartbeat()
                            state.routeManager.disable()
                        }
                    }
                )) {
                    ModeLabel(
                        title: "Heartbeat : ping toutes les 15 s",
                        explanation: "Essaie de maintenir la connexion sur l’interface choisie en envoyant un ping toutes les 15 secondes. Si une interface précise est choisie, joseph place temporairement son service réseau en première position et restaure l’ordre original à l’arrêt. Cela nécessite une autorisation administrateur et ne garantit pas qu’un hotspot reste actif."
                    )
                }

                NetworkInterfacePicker(diagnostics: state.networkDiagnostics)
                NetworkRouteView(routeManager: state.routeManager, diagnostics: state.networkDiagnostics)
                SafetySettingsView(controller: state.safetyController)

                if let warning = state.safetyController.warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                    state.routeManager.disable()
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
        openWindow(id: "agent-launcher")
    }
}
