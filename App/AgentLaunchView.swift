import SwiftUI

struct AgentLaunchView: View {
    @ObservedObject var supervisor: AgentSupervisor
    @State private var executablePath = ""
    @State private var arguments = ""

    var body: some View {
        Form {
            HStack(alignment: .top, spacing: 6) {
                Text("Agent")
                    .font(.headline)
                InfoLabel(text: "Un agent est un programme local lancé et surveillé par joseph. Ce n’est pas une fenêtre : cela peut être un script, un serveur, un outil IA, un build ou un conteneur. Une fenêtre ouverte ne lance rien et n’active aucun mode automatiquement.")
            }
            Text("joseph suit le processus lancé, capture ses sorties et maintient le Mac éveillé pendant son exécution.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Chemin absolu de l’exécutable", text: $executablePath)
            TextField("Arguments (séparés par des espaces)", text: $arguments)
            HStack {
                Button("Choisir…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        executablePath = url.path
                    }
                }
                Button("Lancer") {
                    let args = arguments.split(separator: " ").map(String.init)
                    _ = supervisor.launch(executable: executablePath, arguments: args)
                }
                .disabled(executablePath.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
