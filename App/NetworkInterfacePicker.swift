import SwiftUI

struct NetworkInterfacePicker: View {
    @ObservedObject var diagnostics: NetworkDiagnostics

    var body: some View {
        HStack(spacing: 6) {
            Text("Interface heartbeat")
            InfoLabel(text: "Sélectionne l’interface réseau à utiliser pour le heartbeat. L’interface doit être reconnue par macOS comme enX, bridgeX ou une autre interface compatible avec ping. La sélection ne modifie pas l’ordre des services réseau.")
            Spacer()
            Picker("Interface heartbeat", selection: Binding(
                get: { diagnostics.selectedInterfaceName ?? "" },
                set: { diagnostics.selectInterface($0.isEmpty ? nil : $0) }
            )) {
                Text("Automatique").tag("")
                ForEach(diagnostics.interfaces) { interface in
                    Text("\(interface.name) · \(interface.type)")
                        .tag(interface.name)
                }
            }
            .labelsHidden()
        }
        .font(.caption)
    }
}
