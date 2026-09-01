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
                        explanation: "Tant que ce bouton est activé, joseph demande à macOS de maintenir le système éveillé via l’API native IOKit. Il ne modifie pas les réglages permanents de pmset et ne lance aucun processus. Ce n’est pas la même chose que caffeinate : caffeinate vise ici uniquement l’écran avec -d. Le Mode Voyage concerne la veille du système, mais ne garantit pas le fonctionnement capot fermé sur tous les Mac."
                    )
                }
                Toggle(isOn: Binding(
                    get: { state.commandPowerManager.isPMSetEnabled },
                    set: { $0 ? state.commandPowerManager.enablePMSet() : state.commandPowerManager.disablePMSet() }
                )) {
                    ModeLabel(
                        title: "pmset : bloquer la veille",
                        explanation: "Modifie les réglages de veille batterie/secteur avec autorisation administrateur. joseph sauvegarde les valeurs existantes avant modification et les restaure à la désactivation. Mode puissant : il peut augmenter la consommation et la température."
                    )
                }
                Toggle(isOn: Binding(
                    get: { state.commandPowerManager.isCaffeinateEnabled },
                    set: { $0 ? state.commandPowerManager.enableCaffeinate() : state.commandPowerManager.disableCaffeinate() }
                )) {
                    ModeLabel(
                        title: "caffeinate : garder l’écran actif",
                        explanation: "Lance uniquement le processus caffeinate -d appartenant à joseph pour empêcher l’écran de s’éteindre. Aucun réglage permanent n’est modifié et le processus est arrêté à la désactivation."
                    )
                }
                Toggle(isOn: Binding(
                    get: { state.commandPowerManager.isHeartbeatEnabled },
                    set: { $0 ? state.commandPowerManager.enableHeartbeat() : state.commandPowerManager.disableHeartbeat() }
                )) {
                    ModeLabel(
                        title: "Heartbeat : ping toutes les 15 s",
                        explanation: "Lance ping vers 1.1.1.1 toutes les 15 secondes pour maintenir une activité réseau. Cela ne garantit pas que l’iPhone ou l’opérateur conserve le hotspot actif."
                    )
                }

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
