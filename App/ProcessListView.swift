import SwiftUI

struct ProcessListView: View {
    @ObservedObject var supervisor: AgentSupervisor

    var body: some View {
        if supervisor.processes.isEmpty {
            Text("Aucun agent actif")
                .foregroundStyle(.secondary)
        } else {
            ForEach(supervisor.processes) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.command)
                            .lineLimit(1)
                        Spacer()
                        Button("Arrêter") { supervisor.terminate(id: item.id) }
                            .disabled(item.status != .running)
                    }
                    Text(statusText(item.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !item.output.isEmpty {
                        Text(item.output.suffix(160))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private func statusText(_ status: SupervisedProcess.Status) -> String {
        switch status {
        case .running: return "En cours"
        case let .finished(code): return "Terminé (code \(code))"
        case .terminated: return "Interrompu"
        case let .failed(message): return "Échec : \(message)"
        }
    }
}
