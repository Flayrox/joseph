import Foundation
import Network


struct NetworkInterfaceSnapshot: Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let status: String
    let reachability: String
}

@MainActor
final class NetworkDiagnostics: ObservableObject {
    @Published private(set) var interfaces: [NetworkInterfaceSnapshot] = []
    @Published private(set) var pathStatus = "Unknown"
    @Published private(set) var selectedInterfaceName: String?
    @Published private(set) var selectedInterfaceReachability = "Not tested"
    @Published private(set) var selectedInterfaceIsReachable = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.joseph.network-monitor")
    private var probeTimer: Timer?

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
                    status: path.usesInterfaceType($0.type) ? "Active" : "Available",
                    reachability: path.usesInterfaceType($0.type) ? "Route active" : "Not selected"
                )
            }
            Task { @MainActor in
                self?.pathStatus = status
                self?.interfaces = snapshots
                if let selected = self?.selectedInterfaceName, snapshots.contains(where: { $0.name == selected }) == false {
                    self?.selectedInterfaceName = nil
                    self?.selectedInterfaceReachability = "Not available"
                }
            }
        }
        monitor.start(queue: queue)
        probeTimer?.invalidate()
        probeTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.probeSelectedInterface() }
        }
    }

    func selectInterface(_ name: String?) {
        guard name == nil || interfaces.contains(where: { $0.name == name }) else { return }
        selectedInterfaceName = name
        selectedInterfaceReachability = name == nil ? "Automatic" : "Testing…"
        selectedInterfaceIsReachable = false
        probeSelectedInterface()
    }

    func probeSelectedInterface() {
        guard let name = selectedInterfaceName else {
            selectedInterfaceReachability = "Automatic"
            return
        }
        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "1000", "-I", name, "1.1.1.1"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            let result: String
            do {
                try process.run()
                process.waitUntilExit()
                result = process.terminationStatus == 0 ? "Reachable" : "No response"
            } catch {
                result = "Probe failed"
            }
            await MainActor.run {
                self?.selectedInterfaceReachability = result
                self?.selectedInterfaceIsReachable = result == "Reachable"
            }
        }
    }

    func stop() {
        probeTimer?.invalidate()
        probeTimer = nil
        monitor.cancel()
    }

    deinit {
        probeTimer?.invalidate()
        monitor.cancel()
    }
}
