import Foundation
import SwiftUI

struct SupervisedProcess: Identifiable {
    let id: UUID
    let command: String
    let startedAt: Date
    fileprivate let process: Process
}

@MainActor
final class AgentSupervisor: ObservableObject {
    @Published private(set) var processes: [SupervisedProcess] = []
    @Published private(set) var lastError: String?

    private let powerManager: PowerAssertionManager

    init(powerManager: PowerAssertionManager? = nil) {
        self.powerManager = powerManager ?? PowerAssertionManager()
    }

    @discardableResult
    func launch(executable: String, arguments: [String] = [], environment: [String: String]? = nil) -> UUID? {
        let process = Process()
        let executableURL = URL(fileURLWithPath: (executable as NSString).expandingTildeInPath)
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment { process.environment = environment }

        let id = UUID()
        let item = SupervisedProcess(id: id, command: ([executable] + arguments).joined(separator: " "), startedAt: Date(), process: process)
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.didTerminate(id: id) }
        }

        do {
            try process.run()
            processes.append(item)
            _ = powerManager.enableKeepAwake(reason: "JOSEPH: Supervised process")
            josephLog("INFO", "Started process \(id): \(item.command)")
            return id
        } catch {
            lastError = "Unable to launch \(item.command): \(error.localizedDescription)"
            josephLog("ERROR", lastError ?? "Process launch failed")
            return nil
        }
    }

    func terminate(id: UUID) {
        guard let item = processes.first(where: { $0.id == id }) else { return }
        item.process.terminate()
    }

    func terminateAll() {
        processes.forEach { $0.process.terminate() }
    }

    private func didTerminate(id: UUID) {
        processes.removeAll { $0.id == id }
        if processes.isEmpty { powerManager.disableKeepAwake() }
        josephLog("INFO", "Process terminated: \(id)")
    }
}
