import SwiftUI

struct NetworkInterfacePicker: View {
    @ObservedObject var diagnostics: NetworkDiagnostics

    var body: some View {
        HStack(spacing: 6) {
            Text("Interface heartbeat")
            InfoLabel(text: "Sélectionne l’interface réseau à utiliser pour le heartbeat. Si tu choisis une interface précise, joseph essaiera aussi de placer temporairement son service réseau en première position. L’ordre original sera restauré quand le heartbeat sera désactivé.")
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
            Text(diagnostics.selectedInterfaceReachability)
                .foregroundStyle(diagnostics.selectedInterfaceIsReachable ? .green : .secondary)
        }
        .font(.caption)
    }
}
