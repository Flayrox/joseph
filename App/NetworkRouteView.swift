import SwiftUI

struct NetworkRouteView: View {
    @ObservedObject var routeManager: NetworkRouteManager
    @ObservedObject var diagnostics: NetworkDiagnostics

    var body: some View {
        Toggle(isOn: Binding(
            get: { routeManager.isEnabled },
            set: { enabled in
                if enabled { routeManager.enable(preferredInterface: diagnostics.selectedInterfaceName) }
                else { routeManager.disable() }
            }
        )) {
            ModeLabel(
                title: "Route temporaire vers l’interface choisie",
                explanation: "Pendant que ce bouton est activé, joseph place le service réseau correspondant à l’interface choisie en première position avec networksetup. À la désactivation, joseph restaure l’ordre original. Cela nécessite une autorisation administrateur et ne fonctionne que si macOS expose un service correspondant."
            )
        }
        Text("route : \(routeManager.status)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
