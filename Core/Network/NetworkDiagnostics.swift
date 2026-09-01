import Foundation
import Network

struct NetworkInterfaceSnapshot: Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let status: String
}

@MainActor
final class NetworkDiagnostics: ObservableObject {
    @Published private(set) var interfaces: [NetworkInterfaceSnapshot] = []
    @Published private(set) var pathStatus = "Unknown"

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.joseph.network-monitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let status: String
            switch path.status {
            case .satisfied: status = "Connected"
            case .unsatisfied: status = "Unavailable"
            case .requiresConnection: status = "Requires connection"
            @unknown default: status = "Unknown"
            }
            Task { @MainActor in
                self?.pathStatus = status
                self?.interfaces = path.availableInterfaces.map {
                    NetworkInterfaceSnapshot(
                        id: $0.name,
                        name: $0.name,
                        type: String(describing: $0.type),
                        status: path.usesInterfaceType($0.type) ? "Active" : "Available"
                    )
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
