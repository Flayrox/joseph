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
    @Published private(set) var selectedInterfaceName: String?

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
            let snapshots = path.availableInterfaces.map {
                NetworkInterfaceSnapshot(
                    id: $0.name,
                    name: $0.name,
                    type: String(describing: $0.type),
                    status: path.usesInterfaceType($0.type) ? "Active" : "Available"
                )
            }
            Task { @MainActor in
                self?.pathStatus = status
                self?.interfaces = snapshots
                if let selected = self?.selectedInterfaceName, snapshots.contains(where: { $0.name == selected }) == false {
                    self?.selectedInterfaceName = nil
                }
            }
        }
        monitor.start(queue: queue)
    }

    func selectInterface(_ name: String?) {
        guard name == nil || interfaces.contains(where: { $0.name == name }) else { return }
        selectedInterfaceName = name
    }

    func stop() {
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
