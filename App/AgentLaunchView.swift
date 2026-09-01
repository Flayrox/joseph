import SwiftUI

struct AgentLaunchView: View {
    @ObservedObject var supervisor: AgentSupervisor
    @State private var executablePath = ""
    @State private var arguments = ""

    var body: some View {
        Form {
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
