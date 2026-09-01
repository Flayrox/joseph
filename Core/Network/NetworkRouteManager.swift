import Foundation

struct NetworkService: Equatable {
    let name: String
    let device: String?
}

struct NetworkServiceOrderSnapshot: Codable, Equatable {
    let services: [String]
}

enum NetworkServiceOrderParser {
    static func parse(_ output: String) -> [NetworkService] {
        var services: [NetworkService] = []
        var pendingName: String?
        var pendingDevice: String?

        func flush() {
            guard let pendingName else { return }
            services.append(NetworkService(name: pendingName, device: pendingDevice))
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if isServiceLine(line) {
                flush()
                pendingName = serviceName(from: line)
                pendingDevice = nil
                continue
            }

            guard pendingName != nil, let marker = line.range(of: "Device:") else { continue }
            var device = String(line[marker.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if device.last == ")" { device.removeLast() }
            pendingDevice = device.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        flush()
        return services
    }

    private static func isServiceLine(_ line: String) -> Bool {
        guard line.first == "(", let second = line.dropFirst().first else { return false }
        return second.isNumber && line.contains(")")
    }

    private static func serviceName(from line: String) -> String {
        guard let close = line.firstIndex(of: ")") else { return line }
        var name = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        if name.first == "*" {
            name.removeFirst()
            name = name.trimmingCharacters(in: .whitespaces)
        }
        return name
    }
}

@MainActor
final class NetworkRouteManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Disabled"
    @Published private(set) var lastError: String?
    @Published private(set) var preferredServiceName: String?

    private let runner: CommandRunning
    private let snapshotURL: URL
    private var originalOrder: [String]?

    init(runner: CommandRunning = FoundationCommandRunner(), snapshotURL: URL? = nil) {
        self.runner = runner
        self.snapshotURL = snapshotURL ?? Self.defaultSnapshotURL()

        if let snapshot = try? Self.readSnapshot(at: self.snapshotURL) {
            originalOrder = snapshot.services
            isEnabled = true
            status = "Restore required"
            lastError = "A previous joseph session left a temporary network-service order. Disable heartbeat to restore it."
        }
    }

    @discardableResult
    func enable(preferredInterface: String?) -> Bool {
        guard !isEnabled else { return true }
        do {
            guard let preferredInterface, !preferredInterface.isEmpty else {
                throw NetworkRouteError.noInterfaceSelected
            }

            let services = try readServiceOrder()
            guard let preferredService = services.first(where: { $0.device == preferredInterface }) else {
                throw NetworkRouteError.serviceNotFound(preferredInterface)
            }

            let order = services.map(\.name)
            originalOrder = order
            try persistSnapshot(NetworkServiceOrderSnapshot(services: order))

            do {
                let reordered = [preferredService.name] + order.filter { $0 != preferredService.name }
                try apply(order: reordered)
            } catch {
                originalOrder = nil
                try? removeSnapshot()
                throw error
            }

            preferredServiceName = preferredService.name
            isEnabled = true
            status = "Enabled: \(preferredService.name) first"
            lastError = nil
            josephLog("INFO", "Temporary network priority enabled for \(preferredService.name) (\(preferredInterface))")
            return true
        } catch {
            isEnabled = false
            status = "Error"
            lastError = error.localizedDescription
            josephLog("ERROR", "Temporary network priority failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func disable() -> Bool {
        guard let originalOrder = originalOrder ?? (try? Self.readSnapshot(at: snapshotURL))?.services else {
            isEnabled = false
            preferredServiceName = nil
            status = "Disabled"
            return true
        }

        do {
            try apply(order: originalOrder)
            self.originalOrder = nil
            try removeSnapshot()
            isEnabled = false
            preferredServiceName = nil
            status = "Disabled; original order restored"
            lastError = nil
            josephLog("INFO", "Temporary network priority disabled; original order restored")
            return true
        } catch {
            isEnabled = true
            status = "Restore required"
            lastError = error.localizedDescription
            josephLog("CRITICAL", "Network service-order restore failed: \(error.localizedDescription)")
            return false
        }
    }

    private func readServiceOrder() throws -> [NetworkService] {
        let result = try runner.run(
            path: "/usr/sbin/networksetup",
            arguments: ["-listnetworkserviceorder"],
            capturesOutput: true,
            requiresAdministrator: false
        )
        guard result.status == 0 else { throw NetworkRouteError.commandFailed(result.status) }
        let services = NetworkServiceOrderParser.parse(result.output)
        guard !services.isEmpty else { throw NetworkRouteError.noServicesFound }
        return services
    }

    private func apply(order: [String]) throws {
        guard !order.isEmpty else { throw NetworkRouteError.noServicesFound }
        let result = try runner.run(
            path: "/usr/sbin/networksetup",
            arguments: ["-ordernetworkservices"] + order,
            capturesOutput: true,
            requiresAdministrator: true
        )
        guard result.status == 0 else { throw NetworkRouteError.commandFailed(result.status) }
    }

    private func persistSnapshot(_ snapshot: NetworkServiceOrderSnapshot) throws {
        do {
            try FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: snapshotURL, options: .atomic)
        } catch {
            throw NetworkRouteError.snapshotPersistenceFailed(error.localizedDescription)
        }
    }

    private func removeSnapshot() throws {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        try FileManager.default.removeItem(at: snapshotURL)
    }

    private static func readSnapshot(at url: URL) throws -> NetworkServiceOrderSnapshot {
        try JSONDecoder().decode(NetworkServiceOrderSnapshot.self, from: Data(contentsOf: url))
    }

    private static func defaultSnapshotURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("joseph", isDirectory: true)
            .appendingPathComponent("network-service-order.json")
    }
}

enum NetworkRouteError: LocalizedError {
    case noInterfaceSelected
    case serviceNotFound(String)
    case noServicesFound
    case commandFailed(Int32)
    case snapshotPersistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .noInterfaceSelected:
            return "Select a network interface to let joseph temporarily prioritize it."
        case let .serviceNotFound(interface):
            return "No network service is associated with interface \(interface)."
        case .noServicesFound:
            return "macOS returned no network services."
        case let .commandFailed(status):
            return "networksetup failed (status \(status)). Administrator authorization may be required."
        case let .snapshotPersistenceFailed(message):
            return "Could not save the network-service snapshot: \(message)"
        }
    }
}
