import Foundation
import Network

/// Monitors network connectivity using Apple's Network framework
/// Provides accurate online/offline status based on actual network reachability
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// True when the device has network connectivity
    @Published private(set) var isConnected: Bool = true

    /// True when the device is offline (no network connectivity)
    var isOffline: Bool { !isConnected }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
