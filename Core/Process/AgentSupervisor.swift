import Foundation
import SwiftUI

struct SupervisedProcess: Identifiable {
    enum Status: Equatable {
        case running
        case finished(Int32)
        case terminated
        case failed(String)
    }

    let id: UUID
    let command: String
    let startedAt: Date
    fileprivate let process: Process
    fileprivate let outputPipe: Pipe
    fileprivate let errorPipe: Pipe
    fileprivate(set) var status: Status = .running
    fileprivate(set) var output = ""
    fileprivate(set) var errorOutput = ""
}

@MainActor
final class AgentSupervisor: ObservableObject {
    nonisolated static let defaultOutputLimit = 256 * 1024

    @Published private(set) var processes: [SupervisedProcess] = []
    @Published private(set) var lastError: String?

    private let powerManager: PowerAssertionManager
    private let outputLimit: Int

    init(powerManager: PowerAssertionManager? = nil, outputLimit: Int = AgentSupervisor.defaultOutputLimit) {
        self.powerManager = powerManager ?? PowerAssertionManager()
        self.outputLimit = max(1, outputLimit)
    }

    @discardableResult
    func launch(executable: String, arguments: [String] = [], environment: [String: String]? = nil) -> UUID? {
        let path = (executable as NSString).expandingTildeInPath
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else {
            lastError = "Executable is not an executable absolute path: \(executable)"
            josephLog("ERROR", lastError ?? "Invalid executable")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let environment { process.environment = environment }
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let id = UUID()
        let command = ([path] + arguments).joined(separator: " ")
        let item = SupervisedProcess(id: id, command: command, startedAt: Date(), process: process, outputPipe: outputPipe, errorPipe: errorPipe)

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.appendOutput(text, to: id, isError: false) }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.appendOutput(text, to: id, isError: true) }
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.didTerminate(id: id, status: process.terminationStatus, reason: process.terminationReason)
            }
        }

        do {
            try process.run()
            processes.append(item)
            _ = powerManager.enableKeepAwake(reason: "JOSEPH: Supervised process")
            josephLog("INFO", "Started process \(id): \(command)")
            return id
        } catch {
            cleanup(item)
            lastError = "Unable to launch \(command): \(error.localizedDescription)"
            josephLog("ERROR", lastError ?? "Process launch failed")
            return nil
        }
    }

    func terminate(id: UUID) {
        guard let item = processes.first(where: { $0.id == id }), item.process.isRunning else { return }
        item.process.terminate()
    }

    func terminateAll() {
        processes.filter { $0.process.isRunning }.forEach { $0.process.terminate() }
    }

    private func appendOutput(_ text: String, to id: UUID, isError: Bool) {
        guard let index = processes.firstIndex(where: { $0.id == id }) else { return }
        if isError {
            processes[index].errorOutput = boundedAppend(processes[index].errorOutput, text)
        } else {
            processes[index].output = boundedAppend(processes[index].output, text)
        }
    }

    private func boundedAppend(_ current: String, _ addition: String) -> String {
        let combined = current + addition
        guard combined.utf8.count > outputLimit else { return combined }
        let suffix = combined.suffix(outputLimit)
        return "[… output truncated …]\n" + suffix
    }

    private func didTerminate(id: UUID, status: Int32, reason: Process.TerminationReason) {
        guard let index = processes.firstIndex(where: { $0.id == id }) else { return }
        let item = processes[index]
        cleanup(item)
        processes[index].status = reason == .uncaughtSignal ? .terminated : .finished(status)
        if processes.allSatisfy({ !$0.process.isRunning }) { powerManager.disableKeepAwake() }
        josephLog("INFO", "Process terminated: \(id), status=\(status)")
    }

    private func cleanup(_ item: SupervisedProcess) {
        item.outputPipe.fileHandleForReading.readabilityHandler = nil
        item.errorPipe.fileHandleForReading.readabilityHandler = nil
        item.process.terminationHandler = nil
    }
}
