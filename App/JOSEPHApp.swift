import SwiftUI

@main
struct josephApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("joseph", systemImage: state.powerManager.isActive || state.commandPowerManager.isPMSetEnabled ? "bolt.fill" : "bolt.slash") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(nsImage: logoImage(named: "logo.png"))
                        .resizable()
                        .scaledToFit()
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
            AgentLaunchView(supervisor: state.supervisor)
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

    private func logoImage(named name: String) -> NSImage {
        if let image = NSImage(named: name) { return image }
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 20, height: 20)).fill()
        image.unlockFocus()
        return image
    }
}
